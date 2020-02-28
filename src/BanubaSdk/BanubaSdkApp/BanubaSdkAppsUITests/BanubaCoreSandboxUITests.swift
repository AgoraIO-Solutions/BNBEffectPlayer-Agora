//
//  BanubaCoreSandboxUITests.swift
//  BanubaCoreSandboxUITests
//
//  Created by Victor Privalov on 8/24/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import XCTest

class BanubaCoreSandboxUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launch()
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNoOp() {
    }
    
    func testTakePhoto() {
        app.buttons["shuter foto"].tap()
        app.buttons["back btn"].tap()
    }

    func testFastVideo() {
        let shutterVideoButton = app.buttons["shutter video"]
        shutterVideoButton.tap()
        shutterVideoButton.tap()
        let button = app.buttons["Done"]
        XCTAssert(button.waitForExistence(timeout: 3))
        button.tap()
    }
    
    func testTakeVideo() {
        let shutterVideoButton = app.buttons["shutter video"]
        shutterVideoButton.tap()
        sleep(2)
        shutterVideoButton.tap()
        let button = app.buttons["Done"]
        XCTAssert(button.waitForExistence(timeout: 3))
        button.tap()
    }
    
    func testReset() {
        print("Run: [0]")
        app.buttons["Clear"].tap()
        app.terminate()
        for runNumber in 1...10  {
            print("Run: [\(runNumber)]")
            app.launch()
            app.buttons["Clear"].tap()
            app.terminate()
        }
    }

    
}
