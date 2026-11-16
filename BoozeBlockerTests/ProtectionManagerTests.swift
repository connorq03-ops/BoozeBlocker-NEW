import XCTest
@testable import BoozeBlocker

final class ProtectionManagerTests: XCTestCase {
    func testActivateWhileActivePreservesSessionAndPersistence() throws {
        let domain = "test.protection.\(UUID().uuidString)"
        let legacyDomain = "test.legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let legacy = try XCTUnwrap(UserDefaults(suiteName: legacyDomain))
        let persistence = PersistenceService(defaults: defaults, legacy: legacy)
        let manager = ProtectionManager(persistence: persistence)
        defer {
            manager.deactivateProtection(reason: .manualStop)
            defaults.removePersistentDomain(forName: domain)
            legacy.removePersistentDomain(forName: legacyDomain)
        }

        manager.activateProtection(duration: 3600)
        manager.recordBlockedAttempt(type: .app, targetName: "Example", targetIdentifier: "com.example.app")
        let original = try XCTUnwrap(manager.currentSession)
        let persistedData = try XCTUnwrap(defaults.data(forKey: SharedKeys.currentSession))
        XCTAssertEqual(original.blockedAttempts.count, 1)

        manager.activateProtection(duration: 60, type: .scheduled)

        let current = try XCTUnwrap(manager.currentSession)
        XCTAssertTrue(manager.isProtectionActive)
        XCTAssertEqual(current.id, original.id)
        XCTAssertEqual(current.startTime, original.startTime)
        XCTAssertEqual(current.blockedAttempts.map(\.id), original.blockedAttempts.map(\.id))
        XCTAssertEqual(defaults.data(forKey: SharedKeys.currentSession), persistedData)
        let reloadedPersistence = PersistenceService(defaults: defaults, legacy: legacy)
        let reloaded = try XCTUnwrap(reloadedPersistence.loadCurrentSession())
        XCTAssertEqual(reloaded.id, original.id)
        XCTAssertEqual(reloaded.startTime, original.startTime)
        XCTAssertEqual(reloaded.blockedAttempts.map(\.id), original.blockedAttempts.map(\.id))

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(current), try encoder.encode(original))
        XCTAssertEqual(try encoder.encode(reloaded), try encoder.encode(original))
        XCTAssertTrue(persistence.loadSessionHistory().isEmpty)
    }
}
