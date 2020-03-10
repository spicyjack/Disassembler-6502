//
//  main.swift
//  Disassembler
//
//  Created by Jacques Légaré on 2020-03-09.
//  Copyright © 2020 Jacques Legare. All rights reserved.
//

import Foundation
import ArgumentParser

enum AddressingMode {
    case absolute       /* size 3 */
    case absoluteX      /* size 3 */
    case absoluteY      /* size 3 */
    case accumulator    /* size 1 */
    case immediate      /* size 2 */
    case implied        /* size 1 */
    case indirect       /* size 3 */
    case indirectX      /* size 2 */
    case indirectY      /* size 2 */
    case relative       /* size 3 */
    case zeroPage       /* size 2 */
    case zeroPageX      /* size 2 */
    case zeroPageY      /* size 2 */
}

let addressingModeSizes: [ AddressingMode: UInt8 ] = [ .absolute: 3,
                                                       .absoluteX: 3,
                                                       .absoluteY: 3,
                                                       .accumulator: 1,
                                                       .immediate: 2,
                                                       .implied: 1,
                                                       .indirect: 3,
                                                       .indirectX: 2,
                                                       .indirectY: 2,
                                                       .relative: 2,
                                                       .zeroPage: 2,
                                                       .zeroPageX: 2,
                                                       .zeroPageY: 2 ]


typealias OpCodePrototype = (id: UInt8, name: String, mode: AddressingMode)

let opCodesPrototypes: [OpCodePrototype] = [ ( 0x00, "BRK", .implied ),
                                             ( 0x01, "ORA", .indirectX ),
                                             ( 0x05, "ORA", .zeroPage ),
                                             ( 0x06, "ASL", .zeroPage ),
                                             ( 0x08, "PHP", .implied ),
                                             ( 0x09, "ORA", .immediate ),
                                             ( 0x0a, "ASL", .accumulator ),
                                             ( 0x0d, "ORA", .absolute ),
                                             ( 0x0e, "ASL", .absolute ),
                                             ( 0x10, "BPL", .relative ),
                                             ( 0x11, "ORA", .indirectY ),
                                             ( 0x15, "ORA", .zeroPageX ),
                                             ( 0x16, "ASL", .zeroPageX ),
                                             ( 0x18, "CLC", .implied ),
                                             ( 0x19, "ORA", .absoluteY ),
                                             ( 0x1d, "ORA", .absoluteX ),
                                             ( 0x1e, "ASL", .absoluteX ),
                                             ( 0x20, "JSR", .absolute ),
                                             ( 0x21, "AND", .indirectX ),
                                             ( 0x24, "BIT", .zeroPage ),
                                             ( 0x25, "AND", .zeroPage ),
                                             ( 0x26, "ROL", .zeroPage ),
                                             ( 0x28, "PLP", .implied ),
                                             ( 0x29, "AND", .immediate ),
                                             ( 0x2a, "ROL", .accumulator ),
                                             ( 0x2c, "BIT", .absolute ),
                                             ( 0x2d, "AND", .absolute ),
                                             ( 0x2e, "ROL", .absolute ),
                                             ( 0x30, "BMI", .relative ),
                                             ( 0x31, "AND", .indirectY ),
                                             ( 0x35, "AND", .zeroPageX ),
                                             ( 0x36, "ROL", .zeroPageX ),
                                             ( 0x38, "SEC", .implied ),
                                             ( 0x39, "AND", .absoluteY ),
                                             ( 0x3d, "AND", .absoluteX ),
                                             ( 0x3e, "ROL", .absoluteX ),
                                             ( 0x40, "RTI", .implied ),
                                             ( 0x41, "EOR", .indirectX ),
                                             ( 0x45, "EOR", .zeroPage ),
                                             ( 0x46, "LSR", .zeroPage ),
                                             ( 0x48, "PHA", .implied ),
                                             ( 0x49, "EOR", .immediate ),
                                             ( 0x4a, "LSR", .accumulator ),
                                             ( 0x4c, "JMP", .absolute ),
                                             ( 0x4d, "EOR", .absolute ),
                                             ( 0x4e, "LSR", .absolute ),
                                             ( 0x50, "BVC", .relative ),
                                             ( 0x51, "EOR", .indirectY ),
                                             ( 0x55, "EOR", .zeroPageX ),
                                             ( 0x56, "LSR", .zeroPageX ),
                                             ( 0x58, "CLI", .implied ),
                                             ( 0x59, "EOR", .absoluteY ),
                                             ( 0x5d, "EOR", .absoluteX ),
                                             ( 0x5e, "LSR", .absoluteX ),
                                             ( 0x60, "RTS", .implied ),
                                             ( 0x61, "ADC", .indirectX ),
                                             ( 0x65, "ADC", .zeroPage ),
                                             ( 0x66, "ROR", .zeroPage ),
                                             ( 0x68, "PLA", .implied ),
                                             ( 0x69, "ADC", .immediate ),
                                             ( 0x6a, "ROR", .accumulator ),
                                             ( 0x6c, "JMP", .indirect ),
                                             ( 0x6d, "ADC", .absolute ),
                                             ( 0x6e, "ROR", .absolute ),
                                             ( 0x70, "BVS", .relative ),
                                             ( 0x71, "ADC", .indirectY ),
                                             ( 0x75, "ADC", .zeroPageX ),
                                             ( 0x76, "ROR", .zeroPageX ),
                                             ( 0x78, "SEI", .implied ),
                                             ( 0x79, "ADC", .absoluteY ),
                                             ( 0x7d, "ADC", .absoluteX ),
                                             ( 0x7e, "ROR", .absoluteX ),
                                             ( 0x81, "STA", .indirectX ),
                                             ( 0x84, "STY", .zeroPage ),
                                             ( 0x85, "STA", .zeroPage ),
                                             ( 0x86, "STX", .zeroPage ),
                                             ( 0x88, "DEY", .implied ),
                                             ( 0x8a, "TXA", .implied ),
                                             ( 0x8c, "STY", .absolute ),
                                             ( 0x8d, "STA", .absolute ),
                                             ( 0x8e, "STX", .absolute ),
                                             ( 0x90, "BCC", .relative ),
                                             ( 0x91, "STA", .indirectY ),
                                             ( 0x94, "STY", .zeroPageX ),
                                             ( 0x95, "STA", .zeroPageX ),
                                             ( 0x96, "STX", .zeroPageY ),
                                             ( 0x98, "TYA", .implied ),
                                             ( 0x99, "STA", .absoluteY ),
                                             ( 0x9a, "TXS", .implied ),
                                             ( 0x9d, "STA", .absoluteX ),
                                             ( 0xa0, "LDY", .immediate ),
                                             ( 0xa1, "LDA", .indirectX ),
                                             ( 0xa2, "LDX", .immediate ),
                                             ( 0xa4, "LDY", .zeroPage ),
                                             ( 0xa5, "LDA", .zeroPage ),
                                             ( 0xa6, "LDX", .zeroPage ),
                                             ( 0xa8, "TAY", .implied ),
                                             ( 0xa9, "LDA", .immediate ),
                                             ( 0xaa, "TAX", .implied ),
                                             ( 0xac, "LDY", .absolute ),
                                             ( 0xad, "LDA", .absolute ),
                                             ( 0xae, "LDX", .absolute ),
                                             ( 0xb0, "BCS", .relative ),
                                             ( 0xb1, "LDA", .indirectY ),
                                             ( 0xb4, "LDY", .zeroPageX ),
                                             ( 0xb5, "LDA", .zeroPageX ),
                                             ( 0xb6, "LDX", .zeroPageY ),
                                             ( 0xb8, "CLV", .implied ),
                                             ( 0xb9, "LDA", .absoluteY ),
                                             ( 0xba, "TSX", .implied ),
                                             ( 0xbc, "LDY", .absoluteX ),
                                             ( 0xbd, "LDA", .absoluteX ),
                                             ( 0xbe, "LDX", .absoluteY ),
                                             ( 0xc0, "CPY", .immediate ),
                                             ( 0xc1, "CMP", .indirectX ),
                                             ( 0xc4, "CPY", .zeroPage ),
                                             ( 0xc5, "CMP", .zeroPage ),
                                             ( 0xc6, "DEC", .zeroPage ),
                                             ( 0xc8, "INY", .implied ),
                                             ( 0xc9, "CMP", .immediate ),
                                             ( 0xca, "DEX", .implied ),
                                             ( 0xcc, "CPY", .absolute ),
                                             ( 0xcd, "CMP", .absolute ),
                                             ( 0xce, "DEC", .absolute ),
                                             ( 0xd0, "BNE", .relative ),
                                             ( 0xd1, "CMP", .indirectY ),
                                             ( 0xd5, "CMP", .zeroPageX ),
                                             ( 0xd6, "DEC", .zeroPageX ),
                                             ( 0xd8, "CLD", .implied ),
                                             ( 0xd9, "CMP", .absoluteY ),
                                             ( 0xdd, "CMP", .absoluteX ),
                                             ( 0xde, "DEC", .absoluteX ),
                                             ( 0xe0, "CPX", .immediate ),
                                             ( 0xe1, "SBC", .indirectX ),
                                             ( 0xe4, "CPX", .zeroPage ),
                                             ( 0xe5, "SBC", .zeroPage ),
                                             ( 0xe6, "INC", .zeroPage ),
                                             ( 0xe8, "INX", .implied ),
                                             ( 0xe9, "SBC", .immediate ),
                                             ( 0xea, "NOP", .implied ),
                                             ( 0xec, "CPX", .absolute ),
                                             ( 0xed, "SBC", .absolute ),
                                             ( 0xee, "INC", .absolute ),
                                             ( 0xf0, "BEQ", .relative ),
                                             ( 0xf1, "SBC", .indirectY ),
                                             ( 0xf5, "SBC", .zeroPageX ),
                                             ( 0xf6, "INC", .zeroPageX ),
                                             ( 0xf8, "SED", .implied ),
                                             ( 0xf9, "SBC", .absoluteY ),
                                             ( 0xfd, "SBC", .absoluteX ),
                                             ( 0xfe, "INC", .absoluteX ), ]

enum OpCode {
    case opCode(id: UInt8, name: String, mode: AddressingMode, arguments: [UInt8])
    case none(value: UInt8)
}

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

struct DisassemblerSequence: Sequence {
    let data: Data
    
    func makeIterator() -> DisassemblerIterator {
        return DisassemblerIterator(self.data)
    }
}

struct DisassemblerIterator: IteratorProtocol {
    let data: Data
    var index: Int = 0
    
    init(_ data: Data) {
        self.data = data
    }
    
    mutating func none() -> OpCode {
        let opCode = OpCode.none(value: data[index])
        index += 1
        return opCode
    }
    
    @discardableResult
    mutating func consume(_ required: UInt8) -> [UInt8] {
        var values = [UInt8]()
        
        for i in index..<(index + Int(required)) {
            values.append(data[i])
        }
        index += Int(required)
        return values
    }
    
    
    func hasAtLeast(_ required: UInt8) -> Bool {
        return index + Int(required) <= data.count
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


func disassemble(data: Data) {
    let disassembler = DisassemblerSequence(data: data)
    var currentAddress = startAddress
    
    for datum in disassembler {
        print(String(format: "%04x: ", currentAddress), terminator: "")
        switch datum {
        case .none(let value):
            print (String(format: "$%02x ", value))
            currentAddress += 1
            
        case .opCode(let id, let name, let mode, let arguments):
            print(String(format: "%02x", id), terminator: " ")
            switch addressingModeSizes[mode] {
            case 1:
                print("      ", terminator: "");
                
            case 2:
                print(String(format: "%02x", arguments[0]), terminator: "    ")
                
            case 3:
                print(String(format: "%02x %02x", arguments[0], arguments[1]), terminator: " ")
                
            default:
                assertionFailure()
            }
            print(name, terminator: " ")
            switch mode {
            case .absolute:
                print(String(format: "$%04x", UInt16(arguments[1]) * 0x100 + UInt16(arguments[0])), terminator: " ")
                
            case .absoluteX:
                print(String(format: "$%04x,X", UInt16(arguments[1]) * 0x100 + UInt16(arguments[0])), terminator: " ")
                
            case .absoluteY:
                print(String(format: "$%04x,Y", UInt16(arguments[1]) * 0x100 + UInt16(arguments[0])), terminator: " ")
                
            case .immediate:
                print(String(format: "#$%02x", arguments[0]), terminator: " ")
                
            case .indirect:
                print(String(format: "($%04x)", UInt16(arguments[1]) * 0x100 + UInt16(arguments[0])), terminator: " ")
                
            case .indirectX:
                print(String(format: "($%02x,X)", arguments[0]), terminator: " ")
                
            case .indirectY:
                print(String(format: "($%02x),Y", arguments[0]), terminator: " ")
                
            case .relative:
                print(String(format: "$%02x", arguments[0]), terminator: " ")
                
            case .zeroPage:
                print(String(format: "$%02x", arguments[0]), terminator: " ")
                
            case .zeroPageX:
                print(String(format: "$%02x,X", arguments[0]), terminator: " ")
                
            case .zeroPageY:
                print(String(format: "$%02x,Y", arguments[0]), terminator: " ")
                
            default:
                print("", terminator: "")
            }
            print()
            currentAddress += UInt16(addressingModeSizes[mode]!)
        }
    }
}

Disassembler.main()

