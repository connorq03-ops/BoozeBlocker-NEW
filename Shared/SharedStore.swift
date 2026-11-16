import Foundation

struct SharedStore {
    let defaults: UserDefaults
    private static let pendingAttemptsLockDirectory: URL = {
        let manager = FileManager.default
        return manager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(AppGroup.id, isDirectory: true)
    }()

    func saveCurrentSession(_ session: ProtectionSession?) {
        _ = withStoreLock { saveCurrentSessionUnlocked(session) }
    }

    private func saveCurrentSessionUnlocked(_ session: ProtectionSession?) {
        if let session = session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: SharedKeys.currentSession)
        } else {
            defaults.removeObject(forKey: SharedKeys.currentSession)
        }
    }

    func loadCurrentSessionReadOnly() -> ProtectionSession? {
        defaults.synchronize()
        return readCurrentSession()
    }

    private func readCurrentSession() -> ProtectionSession? {
        guard let data = defaults.data(forKey: SharedKeys.currentSession),
              let session = try? JSONDecoder().decode(ProtectionSession.self, from: data) else {
            return nil
        }
        return session
    }

    func loadCurrentSession() -> ProtectionSession? {
        withStoreLock {
            guard let session = readCurrentSession() else { return nil }
            if let end = session.scheduledEndTime, end < Date() {
                endCurrentSessionUnlocked(reason: .timerExpired, expectedSessionID: session.id)
                return nil
            }
            return session
        } ?? nil
    }

    func loadSessionHistory() -> [ProtectionSession] {
        defaults.synchronize()
        return readSessionHistory()
    }

    private func readSessionHistory() -> [ProtectionSession] {
        guard let data = defaults.data(forKey: SharedKeys.sessionHistory),
              let history = try? JSONDecoder().decode([ProtectionSession].self, from: data) else {
            return []
        }
        return history
    }

    func addToSessionHistory(_ session: ProtectionSession) {
        _ = withStoreLock { addToSessionHistoryUnlocked(session) }
    }

    private func addToSessionHistoryUnlocked(_ session: ProtectionSession) {
        var history = readSessionHistory()
        guard !history.contains(where: { $0.id == session.id }) else { return }
        history.insert(session, at: 0)
        if let data = try? JSONEncoder().encode(Array(history.prefix(100))) {
            defaults.set(data, forKey: SharedKeys.sessionHistory)
        }
    }

    func clearSessionHistory() {
        defaults.removeObject(forKey: SharedKeys.sessionHistory)
    }

    @discardableResult
    func endCurrentSession(reason: EndReason, expectedSessionID: UUID? = nil) -> ProtectionSession? {
        withStoreLock {
            endCurrentSessionUnlocked(reason: reason, expectedSessionID: expectedSessionID)
        } ?? nil
    }

    @discardableResult
    private func endCurrentSessionUnlocked(reason: EndReason, expectedSessionID: UUID?) -> ProtectionSession? {
        guard var session = readCurrentSession(), session.isActive,
              expectedSessionID == nil || session.id == expectedSessionID else { return nil }
        session.blockedAttempts.append(contentsOf: drainPendingAttemptsUnlocked())
        session.end(reason: reason)
        addToSessionHistoryUnlocked(session)
        saveCurrentSessionUnlocked(nil)
        return session
    }

    func ingestPendingAttempts() -> ProtectionSession? {
        withStoreLock {
            guard var session = readCurrentSession(), session.isActive else { return nil }
            session.blockedAttempts.append(contentsOf: drainPendingAttemptsUnlocked())
            saveCurrentSessionUnlocked(session)
            return session
        } ?? nil
    }

    func updateCurrentSession(id: UUID, _ update: (inout ProtectionSession) -> Void) -> ProtectionSession? {
        withStoreLock {
            guard var session = readCurrentSession(), session.isActive, session.id == id else { return nil }
            update(&session)
            saveCurrentSessionUnlocked(session)
            return session
        } ?? nil
    }

    func appendPendingAttempt(type: AttemptType, targetName: String, targetIdentifier: String,
                              outcome: AttemptOutcome = .blocked) {
        _ = withStoreLock {
            var attempts = loadPendingAttempts()
            attempts.append(BlockedAttempt(attemptType: type, targetName: targetName,
                                           targetIdentifier: targetIdentifier, outcome: outcome))
            if let data = try? JSONEncoder().encode(attempts) {
                defaults.set(data, forKey: SharedKeys.pendingAttempts)
            }
        }
    }

    func drainPendingAttempts() -> [BlockedAttempt] {
        withStoreLock { drainPendingAttemptsUnlocked() } ?? []
    }

    private func drainPendingAttemptsUnlocked() -> [BlockedAttempt] {
        let attempts = loadPendingAttempts()
        defaults.removeObject(forKey: SharedKeys.pendingAttempts)
        return attempts
    }

    private func withStoreLock<T>(_ body: () -> T) -> T? {
        let manager = FileManager.default
        let directory = Self.pendingAttemptsLockDirectory
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Cannot create pending-attempt lock directory: \(error)")
            return nil
        }
        let descriptor = open(directory.appendingPathComponent("pending-attempts.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            assertionFailure("Cannot open pending-attempt lock")
            return nil
        }
        defer { close(descriptor) }
        var result: Int32
        repeat { result = flock(descriptor, LOCK_EX) } while result != 0 && errno == EINTR
        guard result == 0 else {
            assertionFailure("Cannot lock pending attempts")
            return nil
        }
        defer { flock(descriptor, LOCK_UN) }
        // Refresh and flush the preferences cache while every process holds the same file lock.
        defaults.synchronize()
        let value = body()
        defaults.synchronize()
        return value
    }

    private func loadPendingAttempts() -> [BlockedAttempt] {
        guard let data = defaults.data(forKey: SharedKeys.pendingAttempts),
              let attempts = try? JSONDecoder().decode([BlockedAttempt].self, from: data) else { return [] }
        return attempts
    }
}
