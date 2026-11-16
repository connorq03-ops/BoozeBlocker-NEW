import XCTest

final class OnboardingSmokeTests: XCTestCase {
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

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "phase1-tabs"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
