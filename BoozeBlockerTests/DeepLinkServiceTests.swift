import XCTest
@testable import BoozeBlocker

final class DeepLinkServiceTests: XCTestCase {
    private let service = DeepLinkService.shared

    override func setUp() {
        super.setUp()
        service.clearPendingAction()
    }

    override func tearDown() {
        service.clearPendingAction()
        super.tearDown()
    }

    func testActivateWithoutDuration() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://activate"))))
        XCTAssertEqual(service.pendingAction, .activate(duration: nil))
    }

    func testActivateWithDuration() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://activate?duration=14400"))))
        XCTAssertEqual(service.pendingAction, .activate(duration: 14400))
    }

    func testActivateWithInvalidDuration() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://activate?duration=invalid"))))
        XCTAssertEqual(service.pendingAction, .activate(duration: nil))
    }

    func testActivateWithNegativeDuration() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://activate?duration=-1"))))
        XCTAssertEqual(service.pendingAction, .activate(duration: nil))
    }

    func testActivateWithZeroDuration() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://activate?duration=0"))))
        XCTAssertEqual(service.pendingAction, .activate(duration: nil))
    }

    func testDeactivate() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://deactivate"))))
        XCTAssertEqual(service.pendingAction, .deactivate)
    }

    func testSettingsWithoutSection() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://settings"))))
        XCTAssertEqual(service.pendingAction, .openSettings(section: nil))
    }

    func testSettingsWithSection() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://settings/apps"))))
        XCTAssertEqual(service.pendingAction, .openSettings(section: "apps"))
    }

    func testHistory() throws {
        XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://history"))))
        XCTAssertEqual(service.pendingAction, .openHistory)
    }

    func testInvalidScheme() throws {
        XCTAssertFalse(service.handle(url: try XCTUnwrap(URL(string: "https://activate"))))
        XCTAssertNil(service.pendingAction)
    }

    func testUnknownRoute() throws {
        XCTAssertFalse(service.handle(url: try XCTUnwrap(URL(string: "boozeblocker://unknown"))))
        XCTAssertNil(service.pendingAction)
    }

    func testClearPendingAction() {
        service.pendingAction = .openHistory
        service.clearPendingAction()
        XCTAssertNil(service.pendingAction)
    }
}
