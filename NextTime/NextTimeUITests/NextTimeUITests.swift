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
    func testDetailedStatisticsEntryRespectsPro() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons.containing(.staticText, identifier: "详细统计").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["升级 Pro"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.append("--store-screenshot-pro")
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons.containing(.staticText, identifier: "详细统计").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["统计"].waitForExistence(timeout: 5))
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
    func testLegacyHistoryDoesNotAdvancePathAndFutureStagesAreVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.start-today"].waitForExistence(timeout: 8))
        app.buttons["home.practice-path"].tap()
        XCTAssertTrue(app.staticTexts["path.position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.position"].label, "学习阶段 1 / 4")
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 0 次")
        XCTAssertFalse(app.buttons["path.review"].isEnabled)
        app.buttons["path.stage.4"].tap()
        XCTAssertTrue(app.staticTexts["巩固与日常应用"].firstMatch.exists)
        XCTAssertFalse(app.buttons["path.review"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "path-future-preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPathRequiresReviewAndPersistsNextStageWithProGuard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "--uitesting-path-review-ready", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.practice-path"].waitForExistence(timeout: 8))
        app.buttons["home.practice-path"].tap()
        XCTAssertTrue(app.staticTexts["path.completed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 1 次")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "path-current-stage"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["path.review"].tap()
        let confirm = app.buttons["path.review.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        for label in ["动作时能保持自然呼吸", "每次收紧后能充分松开", "没有疼痛或持续紧绷等不适"] {
            let control = app.switches[label]
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            XCTAssertEqual(control.value as? String, "1")
        }
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["path.position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.position"].label, "学习阶段 2 / 4")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["home.unlock-today"].waitForExistence(timeout: 5))
        app.buttons["home.unlock-today"].tap()
        XCTAssertTrue(app.navigationBars["升级 Pro"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--store-screenshot-seed" || $0 == "--uitesting-path-review-ready" }
        app.launch()
        XCTAssertTrue(app.buttons["home.practice-path"].waitForExistence(timeout: 8))
        app.buttons["home.practice-path"].tap()
        XCTAssertTrue(app.staticTexts["path.position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.position"].label, "学习阶段 2 / 4")
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 0 次")
    }

    @MainActor
    func testBackgroundPausesTrainingUntilManualResume() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--store-screenshot-seed", "--store-screenshot-pro",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home.start-today"].waitForExistence(timeout: 8))
        app.buttons["home.start-today"].tap()
        XCTAssertTrue(app.buttons["training.exit"].waitForExistence(timeout: 5))
        let control = app.buttons["training.pause-resume"]
        for _ in 0..<6 {
            if control.exists { break }
            let ready = app.buttons["I'm Ready—Continue"]
            XCTAssertTrue(ready.waitForExistence(timeout: 3))
            ready.tap()
        }
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        XCTAssertTrue(control.label.contains("Resume"))
        let remaining = app.staticTexts["training.remaining"]
        let pausedSeconds = remaining.label
        sleep(2)
        XCTAssertEqual(remaining.label, pausedSeconds)
        XCTAssertTrue(control.label.contains("Resume"))
        control.tap()
        XCTAssertTrue(control.label.contains("Pause"))
    }

    @MainActor
    func testPilotNarrationDefaultsFemaleAndPersistsMaleChoice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        func openSettings() {
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
            app.tabBars.buttons.element(boundBy: 3).tap()
            for _ in 0..<6 {
                if app.buttons["settings.pilot-narration"].isHittable { break }
                app.swipeUp()
            }
        }
        openSettings()
        app.buttons["settings.pilot-narration"].tap()
        XCTAssertTrue(app.staticTexts["pilot.voice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pilot.voice"].label, "女声 · 默认")
        let playback = app.buttons["pilot.play-pause"]
        XCTAssertTrue(playback.exists)
        playback.tap()
        let elapsed = app.staticTexts["pilot.elapsed"]
        let advanced = NSPredicate(format: "label != %@", "0:00")
        expectation(for: advanced, evaluatedWith: elapsed)
        waitForExpectations(timeout: 5)
        playback.tap()
        let pausedTime = elapsed.label
        sleep(2)
        XCTAssertEqual(elapsed.label, pausedTime)
        app.buttons["完成"].tap()
        app.buttons["settings.narration-voice"].tap()
        app.buttons["男声"].tap()
        app.buttons["settings.pilot-narration"].tap()
        XCTAssertTrue(app.staticTexts["pilot.voice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pilot.voice"].label, "男声")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--store-screenshot-seed" }
        app.launch()
        openSettings()
        app.buttons["settings.pilot-narration"].tap()
        XCTAssertTrue(app.staticTexts["pilot.voice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pilot.voice"].label, "男声")
    }

    @MainActor
    func testRecordedStageOneFullSessionSavesOnceAndUnsureKeepsStage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshot-seed", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.start-today"].waitForExistence(timeout: 8))
        app.buttons["home.start-today"].tap()
        let section = app.staticTexts["training.recorded-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertTrue(section.label.contains("认识动作"))
        let pause = app.buttons["training.pause-resume"]
        XCTAssertTrue(pause.exists)
        pause.tap()
        let remaining = app.staticTexts["training.remaining"].label
        sleep(2)
        XCTAssertEqual(app.staticTexts["training.remaining"].label, remaining)
        pause.tap()
        let ready = app.buttons["training.continue"]
        XCTAssertTrue(ready.waitForExistence(timeout: 75))
        ready.tap()
        let hiddenReady = NSPredicate(format: "exists == false")
        expectation(for: hiddenReady, evaluatedWith: ready)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(ready.waitForExistence(timeout: 45))
        ready.tap()
        let demo = NSPredicate(format: "label CONTAINS %@", "示范 · 第1/2次")
        expectation(for: demo, evaluatedWith: section)
        waitForExpectations(timeout: 5)
        let main = NSPredicate(format: "label CONTAINS %@", "主练习 · 第1/6次")
        expectation(for: main, evaluatedWith: section)
        waitForExpectations(timeout: 50)
        XCTAssertTrue(app.staticTexts["training.next-action"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "stage-one-real-practice"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(app.staticTexts["training.completed-label"].waitForExistence(timeout: 145))
        XCTAssertEqual(app.staticTexts["training.repetitions-saved"].label, "主练习完成 6 / 6 次")
        app.buttons["training.feedback.unsure"].tap()
        XCTAssertTrue(app.staticTexts["training.feedback-saved"].waitForExistence(timeout: 5))
        app.buttons["training.open-path"].tap()
        XCTAssertTrue(app.staticTexts["path.position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.position"].label, "学习阶段 1 / 4")
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 1 次")
        XCTAssertFalse(app.buttons["path.review"].isEnabled)
        app.navigationBars.buttons["完成"].tap()
        app.buttons["training.done"].tap()
        XCTAssertTrue(app.buttons["home.practice-path"].waitForExistence(timeout: 5))
        app.buttons["home.practice-path"].tap()
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 1 次")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--store-screenshot-seed" }
        app.launch()
        XCTAssertTrue(app.buttons["home.practice-path"].waitForExistence(timeout: 8))
        app.buttons["home.practice-path"].tap()
        XCTAssertTrue(app.staticTexts["path.completed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["path.completed"].label, "本阶段路径练习已完成 1 次")
        XCTAssertFalse(app.buttons["path.review"].isEnabled)
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

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.browse-programs"].waitForExistence(timeout: 8))
        app.buttons["home.browse-programs"].tap()
        XCTAssertTrue(app.navigationBars["训练课程"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        snapshot("06-optional-courses")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
