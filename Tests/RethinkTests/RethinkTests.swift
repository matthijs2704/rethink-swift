import XCTest
import Rethink
import SCRAM

class RethinkTests: XCTestCase {
    let databaseName = "swift_test"
    let tableName = "swift_test"
    
    private func asyncTest(_ block: (_ callback: @escaping () -> ()) -> ()) {
        let expectFinish = self.expectation(description: "Async tests")
        
        block {
            DispatchQueue.main.async {
                expectFinish.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 30.0) { (err) -> Void in
            if let e = err {
                // Note: referencing self here deliberately to prevent test from being destroyed prematurely
                print("Error=\(e) \(self)")
            }
        }
    }
    
    func testDateConversionExpression() {
        asyncTest { testDoneCallback in
            R.connect(URL(string: "rethinkdb://localhost:28015")!) { (err, connection) in
                XCTAssertNil(err, "Connection error: \(err.debugDescription)")
                
                let date = Date()
                R.expr(date).run(connection) { (response) in
                    XCTAssertFalse(response.isError, "Failed to date: \(response)")
                    XCTAssertTrue(response.value is Date, "Failed to date: \(response)")
                    print(response)
                    testDoneCallback()
                }
            }
        }
    }
    
    func testDateNowExpression() {
        asyncTest { testDoneCallback in
            R.connect(URL(string: "rethinkdb://localhost:28015")!) { (err, connection) in
                XCTAssertNil(err, "Connection error: \(err.debugDescription)")
                
                R.now().run(connection) { (response) in
                    XCTAssert(!response.isError && response.value is NSDate, "Failed to date: \(response)")
                    print(response)
                    testDoneCallback()
                }
            }
        }
    }
    
    func testRangeExpression() {
        asyncTest { testDoneCallback in
            R.connect(URL(string: "rethinkdb://localhost:28015")!) { (err, connection) in
                XCTAssertNil(err, "Connection error: \(err.debugDescription)")
                
                R.range(1, 10).map { e in return e.mul(10) }.run(connection) { response in
                    if let r = response.value as? [Int] {
                        XCTAssert(r == Array(1..<10).map { return $0 * 10 })
                        testDoneCallback()
                    }
                    else {
                        XCTAssert(false, "invalid response")
                    }
                }
            }
        }
    }
    
    func testBasicCommands() {
        asyncTest { testDoneCallback in
            R.connect(URL(string: "rethinkdb://localhost:28015")!) { (err, connection) in
                XCTAssertNil(err, "Connection error: \(err.debugDescription)")
                
                print("Connected!")
                
                
                var outstanding = 100
                var outstandingChanges = 1000
                var reader : ReResponse.Callback? = nil
                reader = { (response) -> () in
                    XCTAssert(!response.isError, "Failed to fetch documents: \(response)")
                    
                    switch response {
                    case .rows(_, let cont):
                        if cont == nil {
                            outstanding -= 1
                            print("Outstanding=\(outstanding) outstanding changes=\(outstandingChanges)")
                            if outstanding == 0 && outstandingChanges == 0 {
                                testDoneCallback()
                            }
                        }
                        cont?(reader!)
                        
                    default:
                        print("Unknown response")
                    }
                }
                
                R.dbCreate(self.databaseName).run(connection) { (response) in
                    XCTAssert(!response.isError, "Failed to create database: \(response)")
                    
                    R.dbList().run(connection) { (response) in
                        XCTAssert(!response.isError, "Failed to dbList: \(response)")
                        XCTAssert(response.value is NSArray && (response.value as! NSArray).contains(self.databaseName), "Created database not listed in response")
                    }
                    
                    R.db(self.databaseName).tableCreate(self.self.tableName).run(connection) { (response) in
                        XCTAssert(!response.isError, "Failed to create table: \(response)")
                        
                        R.db(self.databaseName).table(self.tableName).indexWait().run(connection) { (response) in
                            XCTAssert(!response.isError, "Failed to wait for index: \(response)")
                            
                            R.db(self.databaseName).table(self.tableName).changes().run(connection) { response in
                                XCTAssert(!response.isError, "Failed to obtain changes: \(response)")
                                
                                var consumeChanges: ((_ response: ReResponse) -> ())? = nil
                                
                                consumeChanges = { (response: ReResponse) -> () in
                                    if case ReResponse.rows(let docs, let cb) = response {
                                        outstandingChanges -= docs.count
                                        print("Received \(docs.count) changes, need \(outstandingChanges) more")
                                        cb!(consumeChanges!)
                                    }
                                    else {
                                        print("Received unexpected response for .changes request: \(response)")
                                    }
                                }
                                
                                consumeChanges!(response)
                                
                            }
                            
                            // Insert 1000 documents
                            var docs: [ReDocument] = []
                            for i in 0..<1000 {
                                docs.append(["foo": "bar", "id": i])
                            }
                            
                            R.db(self.databaseName).table(self.tableName).insert(docs).run(connection) { (response) in
                                XCTAssert(!response.isError, "Failed to insert data: \(response)")
                                
                                R.db(self.databaseName).table(self.tableName).filter({ r in return r["foo"].eq(R.expr("bar")) }).count().run(connection) { (response) in
                                    XCTAssert(!response.isError, "Failed to count: \(response)")
                                    XCTAssert(response.value is NSNumber && (response.value as! NSNumber).intValue == 1000, "Not all documents were inserted, or count is failing: \(response)")
                                    
                                    for _ in 0..<outstanding {
                                        R.db(self.databaseName).table(self.tableName).run(connection, callback: reader!)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        let expectFinish = self.expectation(description: "Cleanup")
        R.connect(URL(string: "rethinkdb://localhost:28015")!) { (err, connection) in
            if err != nil { print("Connection error: \(err.debugDescription)") }

            R.dbDrop(self.databaseName).run(connection) { (response) in
                if !response.isError { print("Failed to drop database: \(response)") }
                DispatchQueue.main.async {
                    expectFinish.fulfill()
                }
            }
        }
        
        self.waitForExpectations(timeout: 30.0)
    }
}

extension RethinkTests {
    static var allTests : [(String, (RethinkTests) -> () throws -> Void)] {
        return [
            ("testDateConversionExpression", testDateConversionExpression),
            ("testDateNowExpression", testDateNowExpression),
            ("testRangeExpression", testRangeExpression),
            ("testBasicCommands", testBasicCommands)
        ]
    }
}
