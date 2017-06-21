//
//  Utils.swift
//  SCRAM
//
//  Created by Matthijs Logemann on 21/06/2017.
//

import Foundation

public func xor(_ a: [UInt8], _ b:[UInt8]) -> [UInt8] {
    //    var xored = [UInt8](repeating: 0, count: max(a.count, b.count))
    //    for i in 0..<xored.count {
    //        var aByte: UInt8!
    //        if i >= a.count && i < b.count{
    //            aByte = UInt8(0)
    //        }else {
    //            aByte = a[i]
    //        }
    //
    //        var bByte: UInt8!
    //        if i >= b.count && i < a.count{
    //            bByte = UInt8(0)
    //        }else {
    //            bByte = b[i]
    //        }
    //
    //        xored[i] = aByte ^ bByte
    //    }
    //    return xored
    let dataA = Data.init(bytes: a)
    let dataB = Data.init(bytes: b)
    return dataA.xor(with: dataB).makeBytes()
}

public extension Data {
    public func xor(with data2: Data) -> Data {
        var result = self
        result.withUnsafeMutableBytes() { (dataPtrr: UnsafeMutablePointer<UInt8>)->Void in
            var dataPtr = dataPtrr.pointee
            data2.withUnsafeBytes() { (keyData: UnsafePointer<UInt8>)->Void in
                var keyPtr = keyData.pointee
                var keyIndex: Int = 0
                keyIndex += 1
                for _ in 0..<count {
                    dataPtr = dataPtr ^ keyPtr
                    if dataPtr == 255 {
                        dataPtr = 0
                    }else {
                        dataPtr += 1
                    }
                    if keyPtr == 255 {
                        keyPtr = 0
                    }else {
                        keyPtr += 1
                    }
                    
                    keyIndex += 1
                    if keyIndex == data2.count {
                        keyIndex = 0
                        keyPtr = keyData.pointee
                    }
                }
            }
        }
        return result
    }
}
