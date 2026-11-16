import XCTest
import UserNotifications
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

private final class PausingSessionDefaults: UserDefaults {
    var onSessionRead: (() -> Void)?

    override func data(forKey defaultName: String) -> Data? {
        let value = super.data(forKey: defaultName)
        if defaultName == SharedKeys.currentSession { onSessionRead?() }
        return value
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

    func testSessionIngestionAndExtensionCompletionShareOneTransactionLock() throws {
        let suite = "SessionTransaction.\(UUID().uuidString)"
        let defaults = PausingSessionDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let appStore = SharedStore(defaults: defaults)
        let extensionStore = SharedStore(defaults: UserDefaults(suiteName: suite)!)
        let session = ProtectionSession()
        appStore.saveCurrentSession(session)
        appStore.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "pending")
        let read = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let ended = DispatchSemaphore(value: 0)
        let ingested = DispatchSemaphore(value: 0)
        let ending = DispatchSemaphore(value: 0)
        defaults.onSessionRead = {
            read.signal()
            _ = resume.wait(timeout: .now() + 5)
        }
        DispatchQueue.global().async {
            _ = appStore.ingestPendingAttempts()
            ingested.signal()
        }
        XCTAssertEqual(read.wait(timeout: .now() + 5), .success)
        DispatchQueue.global().async {
            ending.signal()
            extensionStore.endCurrentSession(reason: .timerExpired)
            ended.signal()
        }
        XCTAssertEqual(ending.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(ended.wait(timeout: .now() + 0.1), .timedOut)
        resume.signal()
        XCTAssertEqual(ingested.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(ended.wait(timeout: .now() + 5), .success)
        defaults.onSessionRead = nil
        XCTAssertNil(appStore.loadCurrentSessionReadOnly())
        let history = appStore.loadSessionHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.id, session.id)
        XCTAssertEqual(history.first?.blockedAttempts.map(\.targetIdentifier), ["pending"])
        XCTAssertNil(appStore.ingestPendingAttempts())
        XCTAssertNil(appStore.loadCurrentSessionReadOnly())
    }

    func testIngestionDoesNotDrainOrResurrectMissingEndedOrCorruptSession() {
        let store = store()
        var session = ProtectionSession()
        session.end(reason: .timerExpired)
        for data in [nil, try! JSONEncoder().encode(session), Data("invalid".utf8)] {
            store.defaults.set(data, forKey: SharedKeys.currentSession)
            store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "pending")
            XCTAssertNil(store.ingestPendingAttempts())
            XCTAssertEqual(store.defaults.data(forKey: SharedKeys.currentSession), data)
            XCTAssertEqual(store.drainPendingAttempts().map(\.targetIdentifier), ["pending"])
        }
    }

    func testOnlyMatchingSessionCanBeUpdatedOrCompleted() {
        let store = store()
        let session = ProtectionSession()
        store.saveCurrentSession(session)
        XCTAssertNil(store.endCurrentSession(reason: .manualStop, expectedSessionID: UUID()))
        XCTAssertNil(store.updateCurrentSession(id: UUID()) { $0.scheduledEndTime = Date() })
        XCTAssertEqual(store.loadCurrentSessionReadOnly()?.id, session.id)
        XCTAssertEqual(store.endCurrentSession(reason: .timerExpired)?.id, session.id)
        XCTAssertNil(store.updateCurrentSession(id: session.id) { $0.scheduledEndTime = Date() })
        XCTAssertNil(store.endCurrentSession(reason: .manualStop))
    }

    func testSessionEndedNotificationMatchesAppCopyForAllCounts() {
        for (count, body) in [
            (0, "Great job! No blocked attempts during your session."),
            (1, "You blocked 1 attempt last night!"),
            (2, "You blocked 2 attempts last night!")
        ] {
            let request = SessionEndedNotification.request(blockedAttempts: count)
            XCTAssertEqual(request.identifier, "session_ended")
            XCTAssertEqual(request.content.title, "Protection Ended")
            XCTAssertEqual(request.content.body, body)
            XCTAssertNotNil(request.content.sound)
            XCTAssertNil(request.trigger)
        }
    }

    func testExtensionPostsOnceWithArchivedAndPendingAttemptCount() {
        let store = store()
        var session = ProtectionSession()
        session.addBlockedAttempt(BlockedAttempt(attemptType: .app, targetName: "App", targetIdentifier: "ingested"))
        store.saveCurrentSession(session)
        store.appendPendingAttempt(type: .app, targetName: "App", targetIdentifier: "pending")
        var requests: [UNNotificationRequest] = []
        SessionEndedNotification.endSession(in: store) { requests.append($0) }
        SessionEndedNotification.endSession(in: store) { requests.append($0) }
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.content.body, "You blocked 2 attempts last night!")
        XCTAssertEqual(store.loadSessionHistory().first?.blockedAttempts.count, 2)
        XCTAssertNil(store.endCurrentSession(reason: .manualStop, expectedSessionID: session.id))
    }

    func testExtensionDoesNotNotifyWhenAppAlreadyEndedOrSessionIsMissingOrCorrupt() {
        let store = store()
        let session = ProtectionSession()
        store.saveCurrentSession(session)
        XCTAssertNotNil(store.endCurrentSession(reason: .sobrietyTestPassed, expectedSessionID: session.id))
        SessionEndedNotification.endSession(in: store) { _ in XCTFail("App already ended the session") }
        store.defaults.set(Data("invalid".utf8), forKey: SharedKeys.currentSession)
        SessionEndedNotification.endSession(in: store) { _ in XCTFail("Corrupt session must not notify") }
        store.saveCurrentSession(nil)
        SessionEndedNotification.endSession(in: store) { _ in XCTFail("Missing session must not notify") }
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
