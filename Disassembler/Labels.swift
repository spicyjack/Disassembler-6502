//
//  Labels.swift
//  Disassembler
//
//  Created by Jacques Légaré on 2020-03-17.
//  Copyright © 2020 Jacques Legare. All rights reserved.
//

import Foundation

typealias LabelledAddresses = [ UInt16 : String ]

func fetchLabelledAddresses(targettableAddresses: Set<UInt16>,
                            targettedAddresses: Set<UInt16>,
                            userLabelledAddresses: LabelledAddresses) -> LabelledAddresses {
    var labelledAddresses = userLabelledAddresses
    var labelCounter: Int = 0
    
    targettableAddresses
        .intersection(targettedAddresses)
        .sorted()
        .forEach { address in
            while true {
                let candidate = String(format: "L%04x", labelCounter)
                
                if labelledAddresses.values.contains(candidate) {
                    labelCounter += 1
                } else {
                    labelledAddresses[address] = candidate
                    break
                }
            }
    }

    return labelledAddresses
}

func loadLabelledAddresses(labelledAddresses labelledAddressesFileName: String?,
                           errorsTo errorStream: inout FileHandleOutputStream) throws -> LabelledAddresses {
    if labelledAddressesFileName != nil {
        var labelledAddresses = LabelledAddresses()

        try onEachLine(of: labelledAddressesFileName!) { number, line in
            let fields = line.split(separator: " ")
            
            guard fields.count >= 2 else {
                errorStream.writeln("Unable to parse line \(number + 1) of \(labelledAddressesFileName!).")
                return
            }
            
            let label = String(fields[0])
            guard let address = fromHex(address: String(fields[1])) else {
                errorStream.writeln("Unable to parse \(fields[1]) as an address, on line \(number + 1) of \(labelledAddressesFileName!).")
                return
            }
            
            labelledAddresses[address] = label
        }
        
        return labelledAddresses
    } else {
        return LabelledAddresses()
    }
}
