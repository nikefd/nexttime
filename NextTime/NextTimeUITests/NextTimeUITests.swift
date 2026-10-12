//
//  NextTimeUITests.swift
//  NextTimeUITests
//
//  Created by zhang005 on 1/17/26.
//

import XCTest

final class NextTimeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCompletesRequiredOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset-state"]
        app.launch()

        let adultConfirmation = app.switches["onboarding.adult-confirmation"]
        XCTAssertTrue(adultConfirmation.waitForExistence(timeout: 5))
        adultConfirmation.tap()
        app.buttons["onboarding.continue-button"].tap()

        let safetyConfirmation = app.switches["onboarding.safety-confirmation"]
        XCTAssertTrue(safetyConfirmation.waitForExistence(timeout: 3))
        safetyConfirmation.tap()
        app.buttons["onboarding.continue-button"].tap()

        XCTAssertTrue(safetyConfirmation.waitForNonExistence(timeout: 3))
        app.buttons["onboarding.continue-button"].tap()
        let foundationGoal = app.buttons["onboarding.goal.pelvicFoundation"]
        XCTAssertTrue(foundationGoal.waitForExistence(timeout: 3))
        foundationGoal.tap()
        app.buttons["onboarding.continue-button"].tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testGoalChoicesUseSimplifiedChineseLocalization() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-reset-state",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN"
        ]
        app.launch()

        let adultConfirmation = app.switches["onboarding.adult-confirmation"]
        XCTAssertTrue(adultConfirmation.waitForExistence(timeout: 5))
        adultConfirmation.tap()
        app.buttons["onboarding.continue-button"].tap()
        let safetyConfirmation = app.switches["onboarding.safety-confirmation"]
        XCTAssertTrue(safetyConfirmation.waitForExistence(timeout: 3))
        safetyConfirmation.tap()
        app.buttons["onboarding.continue-button"].tap()
        XCTAssertTrue(safetyConfirmation.waitForNonExistence(timeout: 3))
        app.buttons["onboarding.continue-button"].tap()

        let foundationGoal = app.buttons["onboarding.goal.pelvicFoundation"]
        let relaxationGoal = app.buttons["onboarding.goal.relaxation"]
        XCTAssertTrue(foundationGoal.waitForExistence(timeout: 3))
        XCTAssertTrue(relaxationGoal.exists)
        XCTAssertTrue(foundationGoal.label.contains("建立盆底基础"))
        XCTAssertTrue(relaxationGoal.label.contains("学会充分放松"))
        XCTAssertFalse(foundationGoal.label.contains("Build pelvic floor foundations"))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
