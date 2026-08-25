import XCTest

final class EchoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

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
}
