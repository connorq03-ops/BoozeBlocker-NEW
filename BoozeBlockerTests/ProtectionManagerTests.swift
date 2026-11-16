import XCTest
@testable import BoozeBlocker

final class ProtectionManagerTests: XCTestCase {
    func testActivateWhileActivePreservesSessionAndPersistence() throws {
        let domain = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let defaults = UserDefaults.standard
        let savedDomain = defaults.persistentDomain(forName: domain)
        let manager = ProtectionManager.shared
        let persistence = PersistenceService.shared
        manager.deactivateProtection(reason: .manualStop)
        defaults.removePersistentDomain(forName: domain)
        defer {
            manager.deactivateProtection(reason: .manualStop)
            defaults.removePersistentDomain(forName: domain)
            if let savedDomain = savedDomain {
                defaults.setPersistentDomain(savedDomain, forName: domain)
            }
        }

        manager.activateProtection(duration: 3600)
        manager.recordBlockedAttempt(type: .app, targetName: "Example", targetIdentifier: "com.example.app")
        let original = try XCTUnwrap(manager.currentSession)
        let persistedData = try XCTUnwrap(defaults.data(forKey: "currentSession"))
        XCTAssertEqual(original.blockedAttempts.count, 1)

        manager.activateProtection(duration: 60, type: .scheduled)

        let current = try XCTUnwrap(manager.currentSession)
        XCTAssertTrue(manager.isProtectionActive)
        XCTAssertEqual(current.id, original.id)
        XCTAssertEqual(current.startTime, original.startTime)
        XCTAssertEqual(current.blockedAttempts.map(\.id), original.blockedAttempts.map(\.id))
        XCTAssertEqual(defaults.data(forKey: "currentSession"), persistedData)
        let reloaded = try XCTUnwrap(persistence.loadCurrentSession())
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
