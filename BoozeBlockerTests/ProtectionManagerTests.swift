import XCTest
import FamilyControls
@testable import BoozeBlocker

@MainActor
private final class MockBlockingController: BlockingController {
    var authorizationStatus: AuthorizationStatus = .approved
    var selection = FamilyActivitySelection()
    var hasSelection = true
    var isBlocking = false
    var starts: [Date?] = []
    var stops = 0
    var startError: Error?
    func requestAuthorization() async -> Bool { isAuthorized }
    func startBlocking(until endDate: Date?) throws {
        starts.append(endDate)
        if let startError { throw startError }
        isBlocking = isAuthorized && hasSelection
    }
    func stopBlocking() {
        stops += 1
        isBlocking = false
    }
}

@MainActor
final class ProtectionManagerTests: XCTestCase {
    private func fixture() -> (ProtectionManager, PersistenceService, MockBlockingController, UserDefaults) {
        let name = "ProtectionManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let persistence = PersistenceService(defaults: defaults, legacy: defaults)
        let blocker = MockBlockingController()
        let manager = ProtectionManager(persistence: persistence, blocker: blocker)
        return (manager, persistence, blocker, defaults)
    }

    func testActivationAndDeactivationDriveBlockerAndRejectReplacement() async throws {
        let (manager, persistence, blocker, _) = fixture()
        manager.activateProtection(duration: 3600)
        let session = try XCTUnwrap(manager.currentSession)
        XCTAssertEqual(blocker.starts.count, 1)
        XCTAssertEqual(blocker.starts.first!, session.scheduledEndTime)
        XCTAssertTrue(blocker.isBlocking)
        manager.activateProtection(duration: 7200)
        XCTAssertEqual(manager.currentSession?.id, session.id)
        manager.deactivateProtection(reason: .sobrietyTestPassed)
        XCTAssertFalse(blocker.isBlocking)
        XCTAssertNil(persistence.loadCurrentSession())
        XCTAssertEqual(persistence.loadSessionHistory().first?.endReason, .sobrietyTestPassed)
    }

    func testTimerExpiryStopsBlocker() async throws {
        let (manager, persistence, blocker, _) = fixture()
        manager.activateProtection(duration: 0.05)
        try await Task.sleep(for: .seconds(1.3))
        XCTAssertFalse(manager.isProtectionActive)
        XCTAssertFalse(blocker.isBlocking)
        XCTAssertEqual(persistence.loadSessionHistory().first?.endReason, .timerExpired)
    }

    func testExtensionCompletionBeforeAppTickDoesNotArchiveCachedSession() async throws {
        let (manager, persistence, blocker, defaults) = fixture()
        manager.activateProtection(duration: 0.05)
        let sessionID = try XCTUnwrap(manager.currentSession?.id)
        let store = SharedStore(defaults: defaults)
        store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "extension")
        store.endCurrentSession(reason: .timerExpired)
        let ended = try XCTUnwrap(persistence.loadSessionHistory().first)
        try await Task.sleep(for: .seconds(1.3))
        XCTAssertFalse(manager.isProtectionActive)
        XCTAssertFalse(blocker.isBlocking)
        XCTAssertNil(manager.currentSession)
        let history = persistence.loadSessionHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.id, sessionID)
        XCTAssertEqual(history.first?.actualEndTime, ended.actualEndTime)
        XCTAssertEqual(history.first?.blockedAttempts.first?.targetIdentifier, "extension")
        manager.deactivateProtection(reason: .sobrietyTestPassed)
        XCTAssertEqual(persistence.loadSessionHistory().count, 1)
        XCTAssertEqual(persistence.loadSessionHistory().first?.endReason, .timerExpired)
    }

    func testInactiveReconcileResetsFailuresAndCooldownAfterExtensionCompletion() async {
        let (manager, persistence, _, defaults) = fixture()
        manager.activateProtection()
        for _ in 0..<3 { manager.recordSobrietyFailure() }
        XCTAssertGreaterThan(manager.sobrietyCooldownRemaining, 0)
        SharedStore(defaults: defaults).endCurrentSession(reason: .timerExpired)
        manager.reconcile()
        XCTAssertEqual(manager.failedSobrietyAttempts, 0)
        XCTAssertEqual(manager.sobrietyCooldownRemaining, 0)
        XCTAssertEqual(persistence.loadSobrietyFailures(), 0)
        XCTAssertNil(persistence.loadSobrietyCooldown())
        manager.activateProtection()
        manager.requestSobrietyTest()
        XCTAssertTrue(manager.showSobrietyTest)
        manager.deactivateProtection(reason: .sobrietyTestPassed)
    }

    func testInactiveReconcileClearsPartialFailureCount() async {
        let (manager, persistence, _, defaults) = fixture()
        manager.activateProtection()
        manager.recordSobrietyFailure()
        SharedStore(defaults: defaults).endCurrentSession(reason: .timerExpired)
        manager.reconcile()
        XCTAssertEqual(manager.failedSobrietyAttempts, 0)
        XCTAssertEqual(persistence.loadSobrietyFailures(), 0)
    }

    func testUnchangedMonitorDeadlineSurvivesFinalFifteenMinutesAndRelaunch() async throws {
        let (_, _, _, defaults) = fixture()
        var monitoring = false
        var starts = 0
        var stops = 0
        func monitor() -> ProtectionSessionMonitor {
            ProtectionSessionMonitor(defaults: defaults, isMonitoring: { monitoring }, start: { _ in
                starts += 1
                monitoring = true
            }, stop: {
                stops += 1
                monitoring = false
            })
        }
        let now = Date()
        let deadline = now.addingTimeInterval(3600)
        let first = monitor()
        try first.reconcile(until: deadline, now: now)
        let originalStops = stops
        try first.reconcile(until: deadline, now: deadline.addingTimeInterval(-600))
        try monitor().reconcile(until: deadline, now: deadline.addingTimeInterval(-300))
        XCTAssertTrue(monitoring)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, originalStops)
        first.stopMonitoring()
        XCTAssertFalse(monitoring)
        try monitor().reconcile(until: deadline, now: now)
        XCTAssertEqual(starts, 2)
    }

    func testMonitorReschedulesChangedDeadlineAndRetriesMissingOrFailedSchedule() async throws {
        let (_, _, _, defaults) = fixture()
        var monitoring = false
        var starts = 0
        var fail = false
        let monitor = ProtectionSessionMonitor(defaults: defaults, isMonitoring: { monitoring }, start: { _ in
            starts += 1
            if fail { throw NSError(domain: "monitor", code: 1) }
            monitoring = true
        }, stop: { monitoring = false })
        let now = Date()
        let deadline = now.addingTimeInterval(3600)
        try monitor.reconcile(until: deadline, now: now)
        try monitor.reconcile(until: deadline.addingTimeInterval(3600), now: now)
        XCTAssertEqual(starts, 2)
        monitoring = false
        try monitor.reconcile(until: deadline.addingTimeInterval(3600), now: now)
        XCTAssertEqual(starts, 3)
        try monitor.reconcile(until: nil, now: now)
        XCTAssertFalse(monitoring)
        try monitor.reconcile(until: now.addingTimeInterval(600), now: now)
        XCTAssertEqual(starts, 3)
        fail = true
        XCTAssertThrowsError(try monitor.reconcile(until: deadline, now: now))
        fail = false
        try monitor.reconcile(until: deadline, now: now)
        XCTAssertEqual(starts, 5)
        XCTAssertTrue(monitoring)
        try monitor.reconcile(until: deadline.addingTimeInterval(60), now: deadline)
        XCTAssertFalse(monitoring)
        XCTAssertEqual(starts, 5)
    }

    func testLaunchAndForegroundReconcileAndIngest() async throws {
        let (_, persistence, blocker, defaults) = fixture()
        let session = ProtectionSession(scheduledEndTime: Date().addingTimeInterval(3600))
        persistence.saveCurrentSession(session)
        let store = SharedStore(defaults: defaults)
        store.appendPendingAttempt(type: .app, targetName: "Blocked app", targetIdentifier: "token")
        let manager = ProtectionManager(persistence: persistence, blocker: blocker)
        XCTAssertTrue(manager.isProtectionActive)
        XCTAssertTrue(blocker.isBlocking)
        XCTAssertEqual(manager.currentSession?.blockedAttempts.count, 1)
        manager.reconcile()
        XCTAssertEqual(manager.currentSession?.blockedAttempts.count, 1)
        XCTAssertTrue(store.drainPendingAttempts().isEmpty)
        store.endCurrentSession(reason: .timerExpired)
        manager.reconcile()
        XCTAssertFalse(manager.isProtectionActive)
        XCTAssertFalse(blocker.isBlocking)
        XCTAssertNil(manager.currentSession)
    }

    func testExpiredPersistedSessionClearsShields() async {
        let (_, persistence, blocker, _) = fixture()
        persistence.saveCurrentSession(ProtectionSession(scheduledEndTime: Date().addingTimeInterval(-1)))
        blocker.isBlocking = true
        let manager = ProtectionManager(persistence: persistence, blocker: blocker)
        XCTAssertFalse(manager.isProtectionActive)
        XCTAssertFalse(blocker.isBlocking)
        XCTAssertEqual(persistence.loadSessionHistory().first?.endReason, .timerExpired)
    }

    func testWarningsForAuthorizationSelectionAndSchedulingError() async {
        let (manager, _, blocker, _) = fixture()
        blocker.authorizationStatus = .denied
        manager.activateProtection()
        XCTAssertTrue(manager.blockingWarning?.contains("Screen Time") == true)
        manager.deactivateProtection(reason: .manualStop)
        blocker.authorizationStatus = .approved
        blocker.hasSelection = false
        manager.activateProtection()
        XCTAssertTrue(manager.blockingWarning?.contains("No apps selected") == true)
        blocker.hasSelection = true
        blocker.startError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Schedule failed"])
        manager.reconcile()
        XCTAssertTrue(manager.blockingWarning?.contains("Schedule failed") == true)
        manager.deactivateProtection(reason: .manualStop)
        XCTAssertNil(manager.blockingWarning)
    }

    func testDeepLinkDeactivationOnlyPresentsTestAndActivationOpensPicker() async {
        let (manager, _, blocker, _) = fixture()
        manager.handleDeepLink(.deactivate)
        XCTAssertFalse(manager.showSobrietyTest)
        manager.handleDeepLink(.activate(duration: nil))
        XCTAssertTrue(manager.showDurationPicker)
        XCTAssertFalse(manager.isProtectionActive)
        manager.activateProtection()
        manager.handleDeepLink(.deactivate)
        XCTAssertTrue(manager.showSobrietyTest)
        XCTAssertTrue(manager.isProtectionActive)
        XCTAssertTrue(blocker.isBlocking)
        manager.deactivateProtection(reason: .manualStop)
    }

    func testCooldownPersistsAcrossRelaunchAndExpiresAfterTenMinutes() async {
        let (manager, persistence, blocker, _) = fixture()
        manager.activateProtection()
        let now = Date()
        manager.recordSobrietyFailure(now: now)
        manager.recordSobrietyFailure(now: now)
        XCTAssertEqual(manager.sobrietyCooldownRemaining, 0)
        manager.recordSobrietyFailure(now: now)
        XCTAssertEqual(manager.sobrietyCooldownRemaining, 600)
        XCTAssertEqual(manager.sobrietyTestButtonTitle, "Take Sobriety Test (10:00)")
        let relaunched = ProtectionManager(persistence: persistence, blocker: blocker)
        relaunched.handleDeepLink(.deactivate)
        XCTAssertFalse(relaunched.showSobrietyTest)
        XCTAssertGreaterThan(relaunched.sobrietyCooldownRemaining, 590)
        relaunched.recordSobrietyFailure(now: now.addingTimeInterval(60))
        XCTAssertEqual(relaunched.failedSobrietyAttempts, 3)
        relaunched.refreshSobrietyCooldown(now: now.addingTimeInterval(600))
        XCTAssertEqual(relaunched.sobrietyCooldownRemaining, 0)
        XCTAssertEqual(relaunched.failedSobrietyAttempts, 0)
        manager.deactivateProtection(reason: .manualStop)
        relaunched.reconcile()
    }

    func testNoopNeverClaimsAuthorizationOrBlocking() async throws {
        let blocker = NoopBlockingController()
        let authorized = await blocker.requestAuthorization()
        XCTAssertFalse(authorized)
        try blocker.startBlocking(until: nil)
        XCTAssertFalse(blocker.isBlocking)
    }

    func testMorningPresetHasAtLeastOneHour() async {
        XCTAssertGreaterThanOrEqual(Date.timeUntil(hour: 8, minimumDuration: 3600), 3600)
        let hour = Calendar.current.component(.hour, from: Date().addingTimeInterval(1800))
        XCTAssertGreaterThanOrEqual(Date.timeUntil(hour: hour, minimumDuration: 3600), 3600)
    }

    func testLegacyKeysRemovedEvenAfterOriginalMigration() async {
        let (_, persistence, _, defaults) = fixture()
        defaults.set(Data("legacy".utf8), forKey: "blockedApps")
        defaults.set(true, forKey: "screenTimeAuthorized")
        _ = PersistenceService(defaults: defaults, legacy: defaults)
        XCTAssertNil(defaults.object(forKey: "blockedApps"))
        XCTAssertNil(defaults.object(forKey: "screenTimeAuthorized"))
        persistence.saveSobrietyFailures(3)
        persistence.saveSobrietyCooldown(Date().addingTimeInterval(600))
        defaults.set(Data("selection".utf8), forKey: SharedKeys.activitySelection)
        persistence.resetAllData()
        XCTAssertNil(defaults.object(forKey: SharedKeys.activitySelection))
        XCTAssertEqual(persistence.loadSobrietyFailures(), 0)
        XCTAssertNil(persistence.loadSobrietyCooldown())
    }
}
