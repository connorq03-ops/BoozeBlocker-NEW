import XCTest
@testable import BoozeBlocker

final class SharedPersistenceTests: XCTestCase {
    private var suites: [String] = []

    private func defaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suites {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        suites.removeAll()
        super.tearDown()
    }

    func testPersistenceRoundTrip() throws {
        let service = PersistenceService(defaults: defaults(), legacy: defaults())
        let settings = UserSettings(blockedAppBundleIDs: ["com.example.app"], defaultDuration: 14400)
        let session = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(14400))
        service.saveUserSettings(settings)
        service.saveCurrentSession(session)
        service.addToSessionHistory(session)
        XCTAssertEqual(service.loadUserSettings(), settings)
        XCTAssertEqual(service.loadCurrentSession()?.id, session.id)
        XCTAssertEqual(service.loadSessionHistory().map(\.id), [session.id])
        service.saveCurrentSession(nil)
        service.clearSessionHistory()
        XCTAssertNil(service.loadCurrentSession())
        XCTAssertTrue(service.loadSessionHistory().isEmpty)
    }

    func testMigrationCopiesExistingKeysOnlyAndDoesNotRepeat() {
        let shared = defaults()
        let legacy = defaults()
        let keys = [SharedKeys.userSettings, SharedKeys.currentSession, SharedKeys.sessionHistory, SharedKeys.blockedContacts]
        for key in keys { legacy.set(Data(key.utf8), forKey: key) }
        _ = PersistenceService(defaults: shared, legacy: legacy)
        XCTAssertTrue(shared.bool(forKey: SharedKeys.migratedFromStandard))
        for key in keys {
            XCTAssertEqual(shared.data(forKey: key), legacy.data(forKey: key))
            legacy.set(Data("changed".utf8), forKey: key)
        }
        _ = PersistenceService(defaults: shared, legacy: legacy)
        for key in keys { XCTAssertEqual(shared.data(forKey: key), Data(key.utf8)) }

        let emptyLegacy = defaults()
        let destination = defaults()
        destination.set(Data("keep".utf8), forKey: SharedKeys.userSettings)
        _ = PersistenceService(defaults: destination, legacy: emptyLegacy)
        XCTAssertEqual(destination.data(forKey: SharedKeys.userSettings), Data("keep".utf8))
        XCTAssertNil(destination.object(forKey: SharedKeys.currentSession))
    }

    func testSettingsDecodeOldAndEmptyJSON() throws {
        let old = Data(#"{"hasCompletedOnboarding":true,"blockedAppBundleIDs":["com.example.app"]}"#.utf8)
        let settings = try JSONDecoder().decode(UserSettings.self, from: old)
        XCTAssertEqual(settings.blockedAppBundleIDs, ["com.example.app"])
        XCTAssertEqual(settings.defaultDuration, UserSettings().defaultDuration)
        XCTAssertEqual(try JSONDecoder().decode(UserSettings.self, from: Data("{}".utf8)), UserSettings())
        XCTAssertThrowsError(try JSONDecoder().decode(UserSettings.self, from: Data(#"{"blockedAppBundleIDs":false}"#.utf8)))
    }

    func testStoreEmptyCorruptExpiredAndHistoryCap() throws {
        let shared = defaults()
        let store = SharedStore(defaults: shared)
        XCTAssertNil(store.loadCurrentSession())
        XCTAssertTrue(store.loadSessionHistory().isEmpty)
        shared.set(Data("invalid".utf8), forKey: SharedKeys.currentSession)
        shared.set(Data("invalid".utf8), forKey: SharedKeys.sessionHistory)
        XCTAssertNil(store.loadCurrentSession())
        XCTAssertTrue(store.loadSessionHistory().isEmpty)
        let expired = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(-60))
        store.saveCurrentSession(expired)
        XCTAssertNil(store.loadCurrentSession())
        XCTAssertEqual(store.loadSessionHistory().first?.endReason, .timerExpired)
        XCTAssertNil(store.loadCurrentSession())
        XCTAssertEqual(store.loadSessionHistory().count, 1)
        for _ in 0..<101 { store.addToSessionHistory(ProtectionSession()) }
        XCTAssertEqual(store.loadSessionHistory().count, 100)
    }

    func testExtendSessionAddsTwoHours() throws {
        let service = PersistenceService(defaults: defaults(), legacy: defaults())
        let manager = ProtectionManager(persistence: service)
        manager.extendSession(by: 7200)
        XCTAssertNil(manager.currentSession)
        manager.activateProtection()
        manager.extendSession(by: 7200)
        XCTAssertNil(manager.currentSession?.scheduledEndTime)
        manager.activateProtection(duration: 14400)
        defer { manager.deactivateProtection(reason: .manualStop) }
        let end = try XCTUnwrap(manager.currentSession?.scheduledEndTime)
        manager.extendSession(by: 7200)
        XCTAssertEqual(manager.currentSession?.scheduledEndTime, end.addingTimeInterval(7200))
        XCTAssertEqual(service.loadCurrentSession()?.scheduledEndTime, end.addingTimeInterval(7200))
        XCTAssertEqual(try XCTUnwrap(manager.timeRemaining), 21600, accuracy: 2)
    }

    func testFourHourSharedSessionAndMinuteEntries() throws {
        let manager = ProtectionManager.shared
        manager.activateProtection(duration: 4 * 3600)
        defer { manager.deactivateProtection(reason: .manualStop) }
        let session = try XCTUnwrap(SharedStore(defaults: AppGroup.defaults).loadCurrentSession())
        XCTAssertEqual(session.id, manager.currentSession?.id)
        let now = Date()
        let entries = ProtectionEntry.entries(for: session, now: now)
        XCTAssertEqual(entries.count, 241)
        XCTAssertTrue(entries.dropLast().allSatisfy(\.isProtected))
        XCTAssertEqual(entries.first?.date, now)
        for pair in zip(entries.dropLast(2), entries.dropFirst()) {
            XCTAssertEqual(pair.1.date.timeIntervalSince(pair.0.date), 60)
        }
        XCTAssertEqual(entries.last?.date, session.scheduledEndTime)
        XCTAssertEqual(entries.last?.isProtected, false)
    }

    func testEntriesWithoutTimedProtection() {
        let now = Date()
        XCTAssertEqual(ProtectionEntry.entries(for: nil, now: now).count, 1)
        XCTAssertFalse(ProtectionEntry.entries(for: nil, now: now)[0].isProtected)
        let manual = ProtectionEntry.entries(for: ProtectionSession(), now: now)
        XCTAssertEqual(manual.count, 1)
        XCTAssertTrue(manual[0].isProtected)
        XCTAssertNil(manual[0].timeRemaining)
        var ended = ProtectionSession(scheduledEndTime: now.addingTimeInterval(90))
        let timed = ProtectionEntry.entries(for: ended, now: now)
        XCTAssertEqual(timed.count, 3)
        XCTAssertEqual(timed.last?.date, now.addingTimeInterval(90))
        ended.end(reason: .manualStop)
        XCTAssertFalse(ProtectionEntry.entries(for: ended, now: now)[0].isProtected)
        let expired = ProtectionSession(scheduledEndTime: now)
        XCTAssertFalse(ProtectionEntry.entries(for: expired, now: now)[0].isProtected)
    }
}
