//
//  SCRAMTests.swift
//  RethinkTests
//
//  Created by Matthijs Logemann on 21/06/2017.
//

import XCTest
//@testable import SCRAM
import SCRAM

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
        print (result.base64EncodedString())
        //"NBobGxo0"
        // correct: "NBobGxo0"
    }
    
    func testNewXOR() {
//        let testData = "String".data(using: .utf8)! as Data
//        let testKeyData = "Key".data(using: .utf8)! as Data
//        let result = testData.xor(with: testKeyData)
//        print (result.base64EncodedString())
        //"GBELaW5n"
        // correct: "GBELIgse"
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
