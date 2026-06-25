//
//  containerrUITests.swift
//  containerrUITests
//

import XCTest

final class containerrUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesWithWindow() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "The main window should appear on launch.")
    }

    @MainActor
    func testRunWizardOpensAndCancels() throws {
        let app = XCUIApplication()
        app.launch()

        // SwiftUI nests the toolbar button, so several elements share the id.
        let runButton = app.buttons["runContainerButton"].firstMatch
        XCTAssertTrue(runButton.waitForExistence(timeout: 5),
                      "The run-container toolbar button should exist.")
        runButton.click()

        // The wizard sheet should present its Run and Cancel actions.
        let runAction = app.buttons["Run"]
        XCTAssertTrue(runAction.waitForExistence(timeout: 3),
                      "The Run action should appear in the wizard sheet.")
        app.buttons["Cancel"].click()
        XCTAssertFalse(runAction.waitForExistence(timeout: 2),
                       "The wizard should dismiss after Cancel.")
    }
}
