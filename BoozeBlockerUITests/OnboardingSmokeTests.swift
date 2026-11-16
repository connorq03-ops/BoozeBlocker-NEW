import XCTest

final class OnboardingSmokeTests: XCTestCase {
    func testScheduledProtectionIsHiddenByDefault() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState", "YES", "-hasCompletedOnboarding", "YES", "-hasGrantedPermissions", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Scheduled Protection"].exists)
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["Scheduled Protection"].exists)
    }

    func testOnboardingReachesTabs() {
        let app = XCUIApplication(); app.launchArguments = ["-resetState", "YES"]; app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Booze Blocker"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.buttons["Next"].tap() }
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["Permissions Required"].waitForExistence(timeout: 3))
        app.buttons["Skip for Now"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)

        app.tabBars.buttons["Settings"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Blocked Apps")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Blocked Apps"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Screen Time requires a real device"].exists)
        app.tabBars.buttons["Home"].tap()

        app.buttons["Activate Protection"].tap()
        app.buttons["4 hours"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["PROTECTED"].waitForExistence(timeout: 3))
        app.buttons["Stop Protection"].tap()
        app.buttons["Take Sobriety Test"].tap()
        XCTAssertTrue(app.staticTexts["Sobriety Check"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Submit"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "phase1-tabs"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
