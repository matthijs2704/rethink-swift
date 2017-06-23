//
//  Utils.swift
//  SCRAM
//
//  Created by Matthijs Logemann on 21/06/2017.
//

import Foundation
import Bits

public func xor(_ a: [UInt8], _ b:[UInt8]) -> [UInt8] {
    let dataA = Data.init(bytes: a)
    let dataB = Data.init(bytes: b)
    return dataA.xor(with: dataB).makeBytes()
}

public extension Data {
    public func xor(with data2: Data) -> Data {
        var data2 = data2
        if (self.count == 0 || data2.count == 0 || self.count != data2.count) {
            return Data()
        }
        
        var newData = Data(count: self.count)
        
        self.withUnsafeBytes() { (bytesFirst: UnsafePointer<UInt8>) in
            data2.withUnsafeBytes() { (bytesSecond: UnsafePointer<UInt8>) in
                newData.withUnsafeMutableBytes() { (writableBytes: UnsafeMutablePointer<UInt8>) in
                    for i in 0..<self.count {
                        writableBytes[i] = bytesFirst[i] ^ bytesSecond[i]
                    }
                }
            }
        }
        
        return newData
    }
}
