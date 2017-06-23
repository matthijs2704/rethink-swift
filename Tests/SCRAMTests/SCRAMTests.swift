//
//  SCRAMTests.swift
//  RethinkTests
//
//  Created by Matthijs Logemann on 21/06/2017.
//

import XCTest
@testable import SCRAM

class SCRAMTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testXOR() {
        let testData = "String".data(using: .utf8)!
        let testKeyData = "gnirtS".data(using: .utf8)!
        let result = testData.xor(with: testKeyData)
        XCTAssertEqual(result.base64EncodedString(), "NBobGxo0")
    }
    
    func testSCRAM() {
        let s = SCRAM(username: "user", password: "pencil", nonce: "rOprNGfwEbeRWgbNEkqO")
        XCTAssert(!s.authenticated)
        XCTAssert(s.clientFirstMessage() == "n,,n=user,r=rOprNGfwEbeRWgbNEkqO")
        
        do {
        let c2 = try s.receive("r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096")
            XCTAssert(!s.authenticated)
        XCTAssert(c2! == "c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=")
        } catch {
            XCTFail("Could not parse authentication data")
        }
        XCTAssert(!s.authenticated)
        XCTAssert(try s.receive("v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=") == nil)
        XCTAssert(s.authenticated)
    }
    
}
