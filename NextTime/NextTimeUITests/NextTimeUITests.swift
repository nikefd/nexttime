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
        XCTAssertFalse(app.buttons["onboarding.goal.partnerConnection"].exists)
    }

    @MainActor
    func testOptionalLibraryShowsFreeAndProPractices() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let browse = app.buttons["home.browse-programs"]
        XCTAssertTrue(browse.waitForExistence(timeout: 8))
        if !browse.isHittable { app.swipeUp() }
        browse.tap()
        XCTAssertTrue(app.navigationBars["训练课程"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["免费"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Pro"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["伴侣沟通卡"].exists)
        app.swipeDown()
        app.buttons["查看免费与 Pro 权益"].tap()
        XCTAssertTrue(app.staticTexts["免费版已包含"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["全部 18 节个人练习"].exists)
    }

    @MainActor
    func testTodayAdvancedPracticeRequiresPro() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--store-screenshot-seed",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN"
        ]
        app.launch()

        let unlockButton = app.buttons["home.unlock-today"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 8))
        unlockButton.tap()
        XCTAssertTrue(app.navigationBars["升级 Pro"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCaptureStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "--store-screenshot-seed",
            "--store-screenshot-pro",
            "--store-screenshot-price-cn",
            "-AppleInterfaceStyle", "Light",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN"
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.start-today"].waitForExistence(timeout: 5))
        snapshot("01-today-practice")

        app.buttons["home.start-today"].tap()
        XCTAssertTrue(app.buttons["training.exit"].waitForExistence(timeout: 5))
        snapshot("02-natural-guidance")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--store-screenshot-pro" }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["进展"].waitForExistence(timeout: 5))
        snapshot("03-personal-progress")

        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        snapshot("04-local-privacy")

        let upgradeButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "升级 Pro")
        ).firstMatch
        XCTAssertTrue(upgradeButton.waitForExistence(timeout: 5))
        upgradeButton.tap()
        XCTAssertTrue(app.navigationBars["升级 Pro"].waitForExistence(timeout: 5))
        snapshot("05-one-time-pro")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
