//
//  PBKDF2.swift
//  SCRAM
//
//  Created by Matthijs Logemann on 21/06/2017.
//

import Foundation
import Crypto

public enum PBKDF2Error: Error {
    case invalidInput
}

public final class PBKDF2 {
    /// Used for applying an HMAC variant on a password and salt
    private static func digest(_ password: Bytes, data: Bytes) throws -> Bytes {
        return try HMAC.init(.sha256, data).authenticate(key: password)
    }
    
    /// Used to make the block number
    /// Credit to Marcin Krzyzanowski
    private static func blockNumSaltThing(blockNum block: UInt) -> Bytes {
        var inti = Bytes(repeating: 0, count: 4)
        inti[0] = Byte((block >> 24) & 0xFF)
        inti[1] = Byte((block >> 16) & 0xFF)
        inti[2] = Byte((block >> 8) & 0xFF)
        inti[3] = Byte(block & 0xFF)
        return inti
    }
    
    /// Applies the `hi` (PBKDF2 with HMAC as PseudoRandom Function)
    public static func calculate(_ password: Bytes, usingSalt salt: Bytes, iterating iterations: Int, keySize: Int? = nil) throws -> Bytes {
        let keySize = keySize ?? 32
//        guard iterations > 0 && password.count > 0 && salt.count > 0 && keySize <= Int(((pow(2,32) as Double) - 1) * Double(32)) else {
//            throw PBKDF2Error.invalidInput
//        }
        
        let blocks = UInt(ceil(Double(keySize) / Double(32)))
        var response = Bytes()
        
        for block in 1...blocks {
            var s = salt
            s.append(contentsOf: self.blockNumSaltThing(blockNum: block))
            
            var ui = try digest(password, data: s)
            var u1 = ui
            
            for _ in 0..<iterations - 1 {
                u1 = try digest(password, data: u1)
                ui = xor(ui, u1)
            }
            
            response.append(contentsOf: ui)
        }
        
        return response
    }
    
    /// Applies the `hi` (PBKDF2 with HMAC as PseudoRandom Function)
    public static func calculate(_ password: String, usingSalt salt: Bytes, iterating iterations: Int, keySize: Int? = nil) throws -> Bytes {
        return try self.calculate(password.makeBytes(), usingSalt: salt, iterating: iterations, keySize: keySize)
    }
}
