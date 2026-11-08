import XCTest

final class DibslyUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uitest-onboarded"]
        app.launch()
    }

    func testNavigationScreens() throws {
        XCTAssertTrue(app.staticTexts["Nearby"].waitForExistence(timeout: 20), "Feed did not appear")
        snapshot("01-feed-map")

        app.tabBars.buttons["Wanted"].tap()
        XCTAssertTrue(app.navigationBars["Wanted"].waitForExistence(timeout: 6))
        snapshot("02-wanted")

        app.tabBars.buttons["Post"].tap()
        XCTAssertTrue(app.navigationBars["Give something away"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Add"].exists, "Photo adder missing")
        XCTAssertTrue(app.textFields.firstMatch.exists, "Note field missing")
        snapshot("03-post")

        app.tabBars.buttons["Hauls"].tap()
        XCTAssertTrue(app.navigationBars["My Hauls"].waitForExistence(timeout: 6))
        snapshot("04-hauls")

        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 6))
        snapshot("05-profile")

        app.buttons["Settings, AI and support"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        snapshot("06-settings")

        let aiEngine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'AI engine'")).firstMatch
        XCTAssertTrue(aiEngine.waitForExistence(timeout: 6), "AI engine row missing")
        aiEngine.tap()
        XCTAssertTrue(app.navigationBars["AI"].waitForExistence(timeout: 8))
        snapshot("07-ai-config")
        app.buttons["Done"].firstMatch.tap()

        app.swipeUp()
        app.swipeUp()
        sleep(1)
        let contactRow = app.staticTexts["Contact support"]
        XCTAssertTrue(contactRow.waitForExistence(timeout: 6), "Contact support row missing")
        contactRow.tap()
        XCTAssertTrue(app.navigationBars["Contact support"].waitForExistence(timeout: 8))
        snapshot("08-contact-support")
        app.buttons["Close"].firstMatch.tap()

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        let proRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Unlock the quick-grab window'")).firstMatch
        if proRow.exists {
            proRow.tap()
            XCTAssertTrue(app.navigationBars["Dibsly Pro"].waitForExistence(timeout: 8))
            snapshot("09-paywall")
            app.buttons["Close"].firstMatch.tap()
        }

        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 6))
        snapshot("10-profile-final")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
