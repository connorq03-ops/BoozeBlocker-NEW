import XCTest
@testable import BoozeBlocker

final class ProtectionSessionTests: XCTestCase {
    func testActiveSessionHasTimeRemaining() throws {
        let session = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(3600))
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(try XCTUnwrap(session.timeRemaining), 3600, accuracy: 2)
    }

    func testExpiredSessionHasZeroTimeRemainingUntilEnded() {
        let session = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(-60))
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.timeRemaining, 0)
    }

    func testEndedSessionIsInactiveWithNoTimeRemaining() {
        var session = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(3600))
        session.end(reason: .sobrietyTestPassed)
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.timeRemaining)
    }

    func testNewSessionIsActiveWithNoAttempts() {
        let session = ProtectionSession()
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.blockedAttempts.isEmpty)
        XCTAssertNil(session.timeRemaining)
    }
}
