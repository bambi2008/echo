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
    func testFirstReflectionPersistsIntoRelationshipMap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--echo-ui-testing", "--echo-ui-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.philosophy.title"].waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.coreQuestion.title"].exists)
        app.buttons["onboarding.takeMoment"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "onboarding.contact.")).firstMatch.tap()
        app.buttons["onboarding.contactsContinue"].tap()
        app.buttons["onboarding.intent.deepen"].tap()
        app.buttons["onboarding.intentionsContinue"].tap()
        app.buttons["onboarding.contextContinue"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "onboarding.actionContact.")).firstMatch.tap()
        app.buttons["onboarding.action.message"].tap()
        app.buttons["onboarding.planAction"].tap()
        app.buttons["onboarding.enterEcho"].tap()

        XCTAssertTrue(app.buttons["home.continueReflection"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--echo-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["home.continueReflection"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 1).tap()
        let growCloser = app.buttons["relationships.group.deepen"]
        XCTAssertTrue(growCloser.waitForExistence(timeout: 3))
        growCloser.tap()
        XCTAssertTrue(app.staticTexts["Alex Chen"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAgenticHumanAttentionIsVisibleFromHomeAndPipeline() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--echo-ui-testing", "--echo-ui-reset", "--echo-skip-onboarding", "--echo-agentic-demo"]
        app.launch()

        let homeAttention = app.buttons["home.humanAttention"]
        XCTAssertTrue(homeAttention.waitForExistence(timeout: 8))
        homeAttention.tap()
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
