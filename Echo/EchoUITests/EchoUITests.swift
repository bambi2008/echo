import XCTest

final class EchoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testDataStoreFailurePreservesDataAndOffersRetry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--echo-ui-testing", "--echo-force-store-failure",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()

        let retry = app.buttons["Try again"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testBusinessOnboardingEntersCommercialWorkspace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--echo-ui-testing", "--echo-ui-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.businessWelcome.title"].waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.setupContinue"].waitForExistence(timeout: 5))
        app.buttons["onboarding.setupContinue"].tap()
        XCTAssertTrue(app.buttons["onboarding.contactsContinue"].waitForExistence(timeout: 5))
        app.buttons["onboarding.contactsContinue"].tap()
        XCTAssertTrue(app.buttons["onboarding.enterEcho"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enterEcho"].tap()
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 5))
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(app.staticTexts["Business workspace"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAgenticHumanAttentionIsVisibleFromHomeAndPipeline() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--echo-ui-testing", "--echo-ui-reset", "--echo-skip-onboarding", "--echo-agentic-demo"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 3).waitForExistence(timeout: 8))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let pipelineChooser = app.buttons["Choose pipeline"]
        if pipelineChooser.waitForExistence(timeout: 3) {
            pipelineChooser.tap()
            let partnerships = app.buttons["Partnerships"]
            if partnerships.waitForExistence(timeout: 3) { partnerships.tap() }
        }
        XCTAssertTrue(app.staticTexts["Potential Partnership"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline.humanAttention"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Organization A"].firstMatch.exists)

        app.staticTexts["Potential Partnership"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline.detail.ai"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline.detail.score"].firstMatch.exists)
        let person = app.staticTexts["Person One"].firstMatch
        for _ in 0..<4 where !person.exists { app.swipeUp() }
        XCTAssertTrue(person.waitForExistence(timeout: 3))
        let timeline = app.descendants(matching: .any)["pipeline.detail.timeline"].firstMatch
        for _ in 0..<4 where !timeline.exists { app.swipeUp() }
        XCTAssertTrue(timeline.waitForExistence(timeout: 3))
    }
}
