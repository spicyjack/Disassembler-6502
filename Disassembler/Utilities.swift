//
//  Utilities.swift
//  Disassembler
//
//  Created by Jacques Légaré on 2020-03-16.
//  Copyright © 2020 Jacques Legare. All rights reserved.
//

import Foundation

func fromHex(address: String) -> UInt16? {
    if address.hasPrefix("0x") {
        return UInt16(address.dropFirst(2), radix: 16)
    } else {
        return UInt16(address)
    }
}

func fromHex(value: String) -> UInt8? {
    if value.hasPrefix("0x") {
        return UInt8(value.dropFirst(2), radix: 16)
    } else {
        return UInt8(value)
    }
}

func onEachLine(of fileName: String, _ continuation: (Int, String) -> ()) throws {
    let numberedLines = try String(contentsOfFile: fileName).split { $0.isNewline }.enumerated()
    
    for ( number, line ) in numberedLines {
        continuation(number, String(line))
    }
}
