import XCTest
@testable import BoozeBlocker

final class ProtectionSessionTests: XCTestCase {
    func testNewSessionIsActiveWithNoAttempts() {
        let session = ProtectionSession()
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.blockedAttempts.isEmpty)
        XCTAssertNil(session.timeRemaining)
    }
}
