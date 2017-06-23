//
//  LinuxTests.swift
//  Rethink
//
//  Created by Matthijs Logemann on 23/06/2017.
//
//

import XCTest
@testable import SCRAMTests
@testable import RethinkTests

XCTMain([
    testCase(SCRAMTests.allTests),
    testCase(RethinkTests.allTests)
    ])
