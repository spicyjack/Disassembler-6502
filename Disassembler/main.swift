//
//  main.swift
//  Disassembler
//
//  Created by Jacques Légaré on 2020-03-09.
//  Copyright © 2020 Jacques Legare. All rights reserved.
//

import Foundation
import ArgumentParser

let startAddress: UInt16 = 0x1000

struct Disassembler: ParsableCommand {
    @Argument(help: "file name")
    var fileName: String
    
    func run() throws {
        let url = URL(fileURLWithPath: fileName)

        do {
            let data = try Data(contentsOf: url)

            disassemble(data: data)
        } catch {
            print("Couldn't read it!")
        }
    }
}

struct DisassemblerIterator: IteratorProtocol {
    let data: Data
    var index: Int = 0
    
    init(_ data: Data) {
        self.data = data
    }
    
    func hasAtLeast(_ required: UInt8) -> Bool {
        return index + Int(required) <= data.count
    }
    
    mutating func none() -> OpCode {
        let groupSize = 4
        var values = [UInt8]()
        
        while index < data.count && values.count < groupSize {
            if let opCodePrototype = opCodesPrototypes.first(where: { $0.id == data[index] }) {
                let size = addressingModeSizes[opCodePrototype.mode]!
                if hasAtLeast(size) {
                    break
                } else {
                    values.append(data[index])
                    index += 1
                }
            } else {
                values.append(data[index])
                index += 1
            }
        }
        let opCode = OpCode.none(value: values)
        return opCode
    }
    
    mutating func consume(_ required: UInt8) -> [UInt8] {
        var values = [UInt8]()
        
        for i in index..<(index + Int(required)) {
            values.append(data[i])
        }
        index += Int(required)
        return values
    }
    
    mutating func next() -> OpCode? {
        while index < data.count {
            if let opCodePrototype = opCodesPrototypes.first(where: { $0.id == data[index] }) {
                let size = addressingModeSizes[opCodePrototype.mode]!
                if hasAtLeast(size) {
                    var arguments = consume(size)
                    arguments.removeFirst(1)
                    return OpCode.opCode(id: opCodePrototype.id, name: opCodePrototype.name, mode: opCodePrototype.mode, arguments: arguments)
                } else {
                    return none()
                }
            } else {
                return none()
            }
        }
        return nil
    }
}

struct DisassemblerSequence: Sequence {
    let data: Data
    
    func makeIterator() -> DisassemblerIterator {
        return DisassemblerIterator(self.data)
    }
}

func disassemble(data: Data) {
    enum Argument {
        case empty
        case completed(value: String)
        case addressing(template: String, address: UInt16)
    }
    
    typealias AddressedOpCode = ( address: UInt16, opCode: OpCode )
    typealias FormattedOpCode = ( address: UInt16, formattedAddress: String, hexDump: String, name: String, argument: Argument )

    let disassembler = DisassemblerSequence(data: data)
    var currentAddress = startAddress
    var opCodes = [ FormattedOpCode ]()
    
    var targettableAddresses = Set<UInt16>()
    var targettedAddresses = Set<UInt16>()

    func augment(opCode: OpCode) -> ( address: UInt16, OpCode ) {
        let opCodeAddress = currentAddress
        
        switch opCode {
        case .none:
            currentAddress += 1
            
        case .opCode(_, _, let mode, _):
            currentAddress += UInt16(addressingModeSizes[mode]!)
        }
        targettableAddresses.insert(opCodeAddress)
        return ( opCodeAddress, opCode )
    }
    
    func constructAndInternAddress(bytes: [ UInt8 ]) -> UInt16 {
        let address = bytes.reversed().reduce(0x00, { accumulatedAddress, byte in
            accumulatedAddress * 0x100 + UInt16(byte)
        })
        targettedAddresses.insert(address)
        return address
    }
    
    func constructAndInternAddress(relative branch: UInt8, from origin: UInt16) -> UInt16 {
        let address: UInt16 = {
            // In both branches below, we add 2 to the resulting address because we're calculating the target from the start of the OpCode, rather than its end.
            if branch < 128 {
                return origin + UInt16(branch) + 2
            } else {
                return origin - (0x100 - UInt16(branch)) + 2
            }
        }()
        targettedAddresses.insert(address)
        return address
    }

    func formatAddressedOpCode(_ addressedOpCode: AddressedOpCode) -> FormattedOpCode {
        func formatHexDump(id: UInt8, arguments: [ UInt8 ]) -> String {
            return formatHexDump(values: ([ id ] + arguments))
        }

        func formatHexDump(values: [ UInt8 ]) -> String {
            return String(values.map({ String(format: "%02x", $0) }).joined(separator: " ")).padding(toLength: 12, withPad: " ", startingAt: 0)
        }

        let addressField = String(format: "%04x:", addressedOpCode.address)
        var hexDumpField: String
        var nameField = ""
        var argumentField = Argument.empty
        
        switch addressedOpCode.opCode {
        case .none(let values):
            hexDumpField = formatHexDump(values: values)
            
        case .opCode(let id, let name, let mode, let arguments):
            hexDumpField = formatHexDump(id: id, arguments: arguments)
            nameField = name
            argumentField = { () -> Argument in
                switch mode {
                case .absolute:
                    return .addressing(template: "%@", address: constructAndInternAddress(bytes: arguments))
                    
                case .absoluteX:
                    return .addressing(template: "%@,X", address: constructAndInternAddress(bytes: arguments))
                    
                case .absoluteY:
                    return .addressing(template: "%@,Y", address: constructAndInternAddress(bytes: arguments))
                    
                case .immediate:
                    return .completed(value: String(format: "#$%02x", arguments[0]))
                    
                case .indirect:
                    return .addressing(template:"(%@)", address: constructAndInternAddress(bytes: arguments))
                    
                case .indirectX:
                    return .addressing(template: "(%@,X)", address: constructAndInternAddress(bytes: arguments))
                    
                case .indirectY:
                    return .addressing(template: "(%@),Y", address: constructAndInternAddress(bytes: arguments))
                    
                case .relative:
                    return .addressing(template: "%@", address: constructAndInternAddress(relative: arguments[0], from: addressedOpCode.address))
                    
                case .zeroPage:
                    return .addressing(template: "%@", address: constructAndInternAddress(bytes: arguments))
                    
                case .zeroPageX:
                    return .addressing(template: "%@,X", address: constructAndInternAddress(bytes: arguments))
                    
                case .zeroPageY:
                    return .addressing(template: "%@,Y", address: constructAndInternAddress(bytes: arguments))
                    
                default:
                    return .empty
                }
            }()
        }
        return ( address: addressedOpCode.address, formattedAddress: addressField, hexDump: hexDumpField, name: nameField, argument: argumentField )
    }

    opCodes.append(contentsOf: disassembler.map { opCode in formatAddressedOpCode(augment(opCode: opCode)) })
    
    let labels = targettableAddresses
        .intersection(targettedAddresses)
        .sorted()
        .enumerated()
        .map { enumeratedAddress in ( address: enumeratedAddress.element, label: String(format: "L%04x", enumeratedAddress.offset) ) }

    opCodes.forEach { opCode in
        if let label = labels.first(where: { label in label.address == opCode.address }) {
            print(label.label, terminator: " ")
        } else {
            print("      ", terminator: "")
        }
        print(opCode.formattedAddress, opCode.hexDump, opCode.name, terminator: " ")
        switch opCode.argument {
        case .empty:
            print("")
            
        case .completed(let value):
            print(value)
            
        case .addressing(let template, let address):
            if let label = labels.first(where: { label in label.address == address }) {
                print(String(format: template, label.label))
            } else {
                print(String(format: template, String(format: "$%04x", address)))
            }
        }
    }
    
}

Disassembler.main()
