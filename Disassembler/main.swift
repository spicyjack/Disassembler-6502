//
//  main.swift
//  Disassembler
//
//  Created by Jacques Légaré on 2020-03-09.
//  Copyright © 2020 Jacques Legare. All rights reserved.
//

import Foundation
import ArgumentParser

struct UserConfiguration {
    var fileName: String? = nil
    var startAddress: UInt16 = 0x1000

    var addressingModesFileName = "addressingModes.in"
    var opCodePrototypesFileName = "OpCodes.in"
    
    var opCodePrototypes = [ UInt8 : OpCodePrototype ]()
    
    var labelledAddresses = LabelledAddresses()
}

struct Disassembler: ParsableCommand {
    @Argument(help: "Specify input file name.")
    var fileName: String

    @Option(default: "0x1000", help: "Define starting address.")
    var startAddress: String
    
    @Option(help: "Specify path to op-code prototypes.")
    var opCodePrototypesFileName: String?
    
    @Option(help: "Specify path to addressing modes.")
    var addressingModesFileName: String?
    
    @Option(help: "Specify path to pre-defined labels.")
    var labelledAddressesFileName: String?
    
    func run() throws {
        var errorStream = FileHandleOutputStream(fileHandle: FileHandle.standardError)
        var userConfiguration = UserConfiguration(fileName: fileName)
        
        guard let parsedStartAddress = fromHex(address: startAddress) else {
            errorStream.writeln("Unable to parse start address \(startAddress).")
            return
        }
        userConfiguration.startAddress = parsedStartAddress
        
        if addressingModesFileName != nil {
            guard opCodePrototypesFileName != nil else {
                throw ValidationError("An op-code prototypes configuration must be specified when an addressing mode configuration is specified.")
            }
        }
        
        userConfiguration.opCodePrototypes = try loadOpCodePrototypes(addressingModes: addressingModesFileName,
                                                                      opCodePrototypes: opCodePrototypesFileName,
                                                                      errorsTo: &errorStream)
        userConfiguration.labelledAddresses = try loadLabelledAddresses(labelledAddresses: labelledAddressesFileName,
                                                                        errorsTo: &errorStream)
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: fileName))
            var outputStream = FileHandleOutputStream(fileHandle: FileHandle.standardOutput)
            
            disassemble(data: data, outputTo: &outputStream, configuration: userConfiguration)
        } catch {
            errorStream.writeln("Unable to read \(fileName).")
        }
    }
}

struct DisassemblerIterator: IteratorProtocol {
    let data: Data
    let userConfiguration: UserConfiguration
    
    var index: Int = 0
    
    func hasAtLeast(_ required: UInt8) -> Bool {
        return index + Int(required) <= data.count
    }
    
    mutating func none() -> OpCode {
        let groupSize = 4
        var values = [UInt8]()
        
        while index < data.count && values.count < groupSize {
            if let opCodePrototype = userConfiguration.opCodePrototypes[data[index]] {
                let size = opCodePrototype.mode.size
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
        return OpCode.none(value: values)
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
            guard let opCodePrototype = userConfiguration.opCodePrototypes[data[index]] else {
                return none()
            }

            let size = opCodePrototype.mode.size
            
            guard hasAtLeast(size) else {
                return none()
            }

            let id = data[index]
            var arguments = consume(size)
            arguments.removeFirst(1)
            return OpCode.opCode(id: id, name: opCodePrototype.name, mode: opCodePrototype.mode, arguments: arguments)
        }
        return nil
    }
}

struct DisassemblerSequence: Sequence {
    let data: Data
    let userConfiguration: UserConfiguration
    
    func makeIterator() -> DisassemblerIterator {
        return DisassemblerIterator(data: self.data, userConfiguration: self.userConfiguration)
    }
}

func disassemble(data: Data,
                 outputTo outputStream: inout FileHandleOutputStream,
                 configuration userConfiguration: UserConfiguration) {
    enum Argument {
        case empty
        case completed(value: String)
        case addressing(template: String, address: UInt16)
    }
    
    typealias AddressedOpCode = ( address: UInt16, opCode: OpCode )
    typealias FormattedOpCode = ( address: UInt16, formattedAddress: String, hexDump: String, name: String, argument: Argument )

    let disassembler = DisassemblerSequence(data: data, userConfiguration: userConfiguration)
    var currentAddress = userConfiguration.startAddress
    var opCodes = [ FormattedOpCode ]()
    
    var targettableAddresses = Set<UInt16>()
    var targettedAddresses = Set<UInt16>()

    func augment(opCode: OpCode) -> ( address: UInt16, OpCode ) {
        let opCodeAddress = currentAddress
        
        switch opCode {
        case .none:
            currentAddress += 1
            
        case .opCode(_, _, let mode, _):
            currentAddress += UInt16(mode.size)
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
                switch mode.type {
                case .address:
                    return .addressing(template: mode.template, address: constructAndInternAddress(bytes: arguments))
                    
                case .relative:
                    return .addressing(template: mode.template, address: constructAndInternAddress(relative: arguments[0], from: addressedOpCode.address))
                    
                case .value:
                    return .completed(value: String(format: mode.template, arguments[0]))
                    
                case .none:
                    return .empty
                }
            }()
        }
        return ( address: addressedOpCode.address, formattedAddress: addressField, hexDump: hexDumpField, name: nameField, argument: argumentField )
    }

    opCodes.append(contentsOf: disassembler.map { opCode in formatAddressedOpCode(augment(opCode: opCode)) })
    
    let labelledAddresses = fetchLabelledAddresses(targettableAddresses: targettableAddresses,
                                                   targettedAddresses: targettedAddresses,
                                                   userLabelledAddresses: userConfiguration.labelledAddresses)
    opCodes.forEach { opCode in
        if let label = labelledAddresses[opCode.address] {
            outputStream.write(label + " ")
        } else {
            outputStream.write("      ")
        }
        outputStream.write([ opCode.formattedAddress, opCode.hexDump, opCode.name].joined(separator: " ") + " ")
        switch opCode.argument {
        case .empty:
            break

        case .completed(let value):
            outputStream.write(value)
            
        case .addressing(let template, let address):
            if let label = labelledAddresses[address] {
                outputStream.write(String(format: template, label))
            } else {
                outputStream.write(String(format: template, String(format: "$%04x", address)))
            }
        }
        outputStream.writeln("")
    }
    
    if !labelledAddresses.isEmpty {
        outputStream.writeln("\nLABELS")
        labelledAddresses
            .sorted { left, right in left.value < right.value }
            .forEach { element in
                outputStream.writeln(String(format: "      %@: $%04x", element.value, element.key))
        }
    }
}

Disassembler.main()
