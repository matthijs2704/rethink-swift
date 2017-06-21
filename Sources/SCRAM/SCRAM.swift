import Foundation
import Crypto

final public class SCRAM {
    let gs2BindFlag = "n,,"
    
    public var authenticated: Bool
    var awaitingChallenge: Bool
    let username: String
    let password: String
    let clientNonce: String
    var combinedNonce: String? = nil
    var salt: String? = nil
    var count: Int = 0
    var serverMessage1: String? = nil
    var clientFirstMessageBare: String? = nil
    var serverSignatureData: Bytes? = nil
    var clientProofData: Bytes? = nil
    
    public init(username: String, password: String, nonce: String) {
        self.authenticated = false
        self.username = username
        self.password = password
        self.clientNonce = nonce
        self.awaitingChallenge = true
    }
    
    public convenience init(username: String, password: String) {
        self.init(username: username, password: password, nonce: UUID.init().uuidString)
    }
    
    
    private func fixUsername(username user: String) -> String {
        return replaceOccurrences(in: replaceOccurrences(in: user, where: "=", with: "=3D"), where: ",", with: "=2C")
    }
    
//    private func parse(challenge response: String) throws -> (nonce: String, salt: String, iterations: Int) {
//        var nonce: String? = nil
//        var iterations: Int? = nil
//        var salt: String? = nil
//
//        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
//            let part = String(part)
//
//            if let first = part.characters.first {
//                let data = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
//
//                switch first {
//                case "r":
//                    nonce = data
//                case "i":
//                    iterations = Int(data)
//                case "s":
//                    salt = data
//                default:
//                    break
//                }
//            }
//        }
//
//        if let nonce = nonce, let iterations = iterations, let salt = salt {
//            return (nonce: nonce, salt: salt, iterations: iterations)
//        }
//
//        throw SCRAMError.challengeParseError(challenge: response)
//    }
//
//    private func parse(finalResponse response: String) throws -> Bytes {
//        var signature: Bytes? = nil
//
//        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
//            let part = String(part)
//
//            if let first = part.characters.first {
//                let data = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
//
//                switch first {
//                case "v":
//                    signature = data.bytes.base64Decoded
//                default:
//                    break
//                }
//            }
//        }
//
//        if let signature = signature {
//            return signature
//        }
//
//        throw SCRAMError.responseParseError(response: response)
//    }
//
//    public func authenticate(_ username: String, usingNonce nonce: String) -> String {
//        return "\(gs2BindFlag)n=\(fixUsername(username: username)),r=\(nonce)"
//    }
//
//    public func process(_ challenge: String, with details: (username: String, password: Bytes), usingNonce nonce: String) throws -> (proof: String, serverSignature: Bytes) {
//        let encodedHeader = Bytes(gs2BindFlag.utf8).base64Encoded
//
//        let parsedResponse = try parse(challenge: challenge)
//
//        let remoteNonce = parsedResponse.nonce
//
//        guard String(remoteNonce[remoteNonce.startIndex..<remoteNonce.index(remoteNonce.startIndex, offsetBy: 24)]) == nonce else {
//            throw SCRAMError.invalidNonce(nonce: parsedResponse.nonce)
//        }
//
//        let noProof = "c=\(encodedHeader),r=\(parsedResponse.nonce)"
//
//        let salt = parsedResponse.salt.bytes.base64Decoded
//        let saltedPassword = try PBKDF2.calculate(details.password, usingSalt: salt, iterating: parsedResponse.iterations)
//
//        let ck = Bytes("Client Key".utf8)
//        let sk = Bytes("Server Key".utf8)
//
//        let clientKey = try HMAC.init(.sha256, ck).authenticate(key: saltedPassword)
//        let serverKey = try HMAC.init(.sha256, sk).authenticate(key: saltedPassword)
//
//        let storedKey = try Hash.init(.sha256, clientKey).hash()
//
//        let authenticationMessage = "n=\(fixUsername(username: details.username)),r=\(nonce),\(challenge),\(noProof)"
//
//        var authenticationMessageBytes = Bytes()
//        authenticationMessageBytes.append(contentsOf: authenticationMessage.utf8)
//
//        let clientSignature = try HMAC.init(.sha256, authenticationMessageBytes).authenticate(key: storedKey)
//        let clientProof = xor(clientKey, clientSignature)
//        let serverSignature = try HMAC.init(.sha256, authenticationMessageBytes).authenticate(key: serverKey)
//
//        let proof = clientProof.base64Encoded
//
//        return (proof: "\(noProof),p=\(proof)", serverSignature: serverSignature)
//    }
//
//    public func complete(fromResponse response: String, verifying signature: Bytes) throws -> String {
//        let sig = try parse(finalResponse: response)
//
//        if sig != signature {
//            throw SCRAMError.invalidSignature(signature: sig)
//        }
//
//        return ""
//    }
    
    func handleAuth1(_ authResponse: String) throws -> String? {
        let auth = SCRAM.dictionary(from: authResponse)
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        serverMessage1 = authResponse
        combinedNonce = auth["r"]!
        salt = auth["s"]!
        count = numberFormatter.number(from: auth["i"]!)?.intValue ?? 0
        //We have all the necessary information to calculate client proof and server signature
        if try calculateProofs() {
            awaitingChallenge = false
            return clientFinalMessage()
        }
        else {
            return nil
        }
    }
    
    public func clientFirstMessage() -> String {
        self.clientFirstMessageBare = "n=\(username),r=\(clientNonce)"
        return "n,,\(self.clientFirstMessageBare!)"
    }
    
    func clientFinalMessage() -> String {
        let clientProofString: String = String.init(bytes: self.clientProofData!.base64Encoded)
        return "c=biws,r=\(combinedNonce!),p=\(clientProofString)"
    }
    
    private func hashPassword(password: Bytes, salt: Bytes, iterations: Int) throws -> Bytes {
        var mutableSalt = salt
        let zeroHex: UInt8 = 0x00
        let oneHex: UInt8 = 0x01
        
        mutableSalt.append(zeroHex)
        mutableSalt.append(zeroHex)
        mutableSalt.append(zeroHex)
        mutableSalt.append(oneHex)
        
        var result = try HMAC.init(.sha256, mutableSalt).authenticate(key: password)
        var previousResult = Bytes.init(result)
        
        for _ in 1..<iterations {
            previousResult = try HMAC.init(.sha256, mutableSalt).authenticate(key: password)
            result = xor(result, previousResult)
        }
        
        return result
    }
    
    private func calculateProofs() throws -> Bool {
        guard let salt = self.salt else {
            return false
        }
        
        if self.password.count > 0 && self.count < 4096 {
            return false
        }
        
        let passwordData = self.password.makeBytes()
        let saltData = salt.makeBytes()
        
        let saltedPasswordData = try self.hashPassword(password: passwordData, salt: saltData, iterations: self.count)
        
        let clientKeyBytes = try HMAC.init(.sha256, "Client Key".makeBytes()).authenticate(key: saltedPasswordData)
        let serverKeyBytes = try HMAC.init(.sha256, "Server Key".makeBytes()).authenticate(key: saltedPasswordData)
        let storedKeyData = try Hash.init(.sha256, clientKeyBytes).hash()
        
        let authMessageBytes = String.init(format: "%@,%@,c=biws,r=%@", self.clientFirstMessageBare!,self.serverMessage1!,self.combinedNonce!).makeBytes()
        let clientSignatureBytes = try HMAC.init(.sha256, authMessageBytes).authenticate(key: storedKeyData)
        self.serverSignatureData = try HMAC.init(.sha256, authMessageBytes).authenticate(key: serverKeyBytes)
        self.clientProofData = xor(clientKeyBytes, clientSignatureBytes)
        
        if self.clientProofData != nil && self.serverSignatureData != nil {
            return true
        }else {
            return false
        }
    }
    
    private func handleAuth2(_ authResponse: String) {
        let auth = SCRAM.dictionary(from: authResponse)
        let receivedServerSignature = auth["v"]!
        let decoded = receivedServerSignature.makeBytes().base64Decoded
        if let serverSignatureData = self.serverSignatureData, serverSignatureData == decoded {
            authenticated = true
        } else {
            authenticated = false
        }
    }
    
    @discardableResult
    public func receive(_ auth: String) throws -> String? {
        if awaitingChallenge {
            return try handleAuth1(auth)
        }
        else {
            handleAuth2(auth)
            return nil
        }
    }
    
    private static func dictionary(from challenge: String) -> [String : String]{
        let components = challenge.components(separatedBy: ",")
        var auth: [String: String] = [:]
        
        for component in components {
            let separatorOptional = component.range(of: "=")
            guard let separator = separatorOptional else {
                continue
            }
            
            let key = component.substring(to: separator.lowerBound)
            var value = component.substring(from: separator.upperBound)
            
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count > 2 {
                // Strip quotes from value
                value.remove(at: value.startIndex)
                value.remove(at: value.endIndex)
            }
            
            auth[key] = value
        }
        
        return auth
    }
}

/// Replaces occurrences of data with new data in a string
/// Because "having a single cross-platform API for a programming language is stupid"
/// TODO: Remove/update with the next Swift version
internal func replaceOccurrences(`in` string: String, `where` matching: String, with replacement: String) -> String {
    return string.replacingOccurrences(of: matching, with: replacement)
}

public enum SCRAMError: Error {
    case invalidSignature(signature: Bytes)
    case base64Failure(original: Bytes)
    case challengeParseError(challenge: String)
    case responseParseError(response: String)
    case invalidNonce(nonce: String)
}
