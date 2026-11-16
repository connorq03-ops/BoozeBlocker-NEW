import XCTest
@testable import BoozeBlocker

private final class DrainedAttempts: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts: [BlockedAttempt] = []

    func append(_ values: [BlockedAttempt]) {
        lock.lock()
        defer { lock.unlock() }
        attempts.append(contentsOf: values)
    }

    var values: [BlockedAttempt] {
        lock.lock()
        defer { lock.unlock() }
        return attempts
    }
}

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

    func testHistoryDoesNotInsertSameSessionIDAgain() {
        let store = store()
        var session = ProtectionSession()
        session.end(reason: .timerExpired)
        store.addToSessionHistory(session)
        var duplicate = session
        duplicate.end(reason: .manualStop)
        store.addToSessionHistory(duplicate)
        XCTAssertEqual(store.loadSessionHistory().count, 1)
        XCTAssertEqual(store.loadSessionHistory().first?.endReason, .timerExpired)
        XCTAssertEqual(store.loadSessionHistory().first?.actualEndTime, session.actualEndTime)
    }

    func testConcurrentAppendsAndDrainsAcrossStoreInstancesAreNotLostOrDuplicated() {
        let suite = "ConcurrentPendingAttempts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = SharedStore(defaults: defaults)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "attempt-producers", attributes: .concurrent)
        let results = DrainedAttempts()
        for index in 0..<100 {
            group.enter()
            queue.async {
                let writer = SharedStore(defaults: UserDefaults(suiteName: suite)!)
                writer.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "\(index)")
                group.leave()
            }
            group.enter()
            queue.async {
                let reader = SharedStore(defaults: UserDefaults(suiteName: suite)!)
                let attempts = reader.drainPendingAttempts()
                results.append(attempts)
                group.leave()
            }
        }
        group.wait()
        results.append(store.drainPendingAttempts())
        let drained = results.values
        XCTAssertEqual(drained.count, 100)
        XCTAssertEqual(Set(drained.map(\.targetIdentifier)), Set((0..<100).map(String.init)))
        XCTAssertEqual(Set(drained.map(\.id)).count, 100)
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
    }

    func testTokenIDIsStableAndDistinguishesValues() {
        XCTAssertEqual(SharedStore.tokenID(["token": "a"]), SharedStore.tokenID(["token": "a"]))
        XCTAssertNotEqual(SharedStore.tokenID("a"), SharedStore.tokenID("b"))
        XCTAssertEqual(SharedStore.tokenID("a").count, 64)
    }
}
