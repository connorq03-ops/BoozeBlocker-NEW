import XCTest
@testable import BoozeBlocker

final class ScreenTimeSharedStoreTests: XCTestCase {
    private func store() -> SharedStore {
        let suite = "ScreenTimeSharedStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SharedStore(defaults: defaults)
    }

    func testPendingAttemptsRoundTripAndDrain() throws {
        let store = store()
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
        store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "token")
        store.appendPendingAttempt(type: .app, targetName: "Blocked website", targetIdentifier: "domain")
        let attempts = store.drainPendingAttempts()
        XCTAssertEqual(attempts.map(\.targetIdentifier), ["token", "domain"])
        XCTAssertEqual(attempts.first?.outcome, .blocked)
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
    }

    func testPendingAttemptsRecoverFromCorruptData() {
        let store = store()
        store.defaults.set(Data("invalid".utf8), forKey: SharedKeys.pendingAttempts)
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
        XCTAssertNil(store.defaults.object(forKey: SharedKeys.pendingAttempts))
        store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "token")
        XCTAssertEqual(store.drainPendingAttempts().count, 1)
    }

    func testEndSessionIncludesPendingAttemptsAndIsIdempotent() throws {
        let store = store()
        let session = ProtectionSession()
        store.saveCurrentSession(session)
        store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "token")
        store.endCurrentSession(reason: .timerExpired)
        store.endCurrentSession(reason: .manualStop)
        XCTAssertNil(store.loadCurrentSessionReadOnly())
        XCTAssertEqual(store.loadSessionHistory().count, 1)
        let ended = try XCTUnwrap(store.loadSessionHistory().first)
        XCTAssertEqual(ended.id, session.id)
        XCTAssertEqual(ended.endReason, .timerExpired)
        XCTAssertNotNil(ended.actualEndTime)
        XCTAssertEqual(ended.blockedAttempts.first?.targetIdentifier, "token")
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
    }

    func testEndMissingOrCorruptSessionDoesNotCreateHistory() {
        let store = store()
        store.endCurrentSession(reason: .timerExpired)
        store.defaults.set(Data("invalid".utf8), forKey: SharedKeys.currentSession)
        store.endCurrentSession(reason: .timerExpired)
        XCTAssertTrue(store.loadSessionHistory().isEmpty)
    }

    func testTokenIDIsStableAndDistinguishesValues() {
        XCTAssertEqual(SharedStore.tokenID(["token": "a"]), SharedStore.tokenID(["token": "a"]))
        XCTAssertNotEqual(SharedStore.tokenID("a"), SharedStore.tokenID("b"))
        XCTAssertEqual(SharedStore.tokenID("a").count, 64)
    }
}
