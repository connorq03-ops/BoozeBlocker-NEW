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
        if let session = session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: SharedKeys.currentSession)
        } else {
            defaults.removeObject(forKey: SharedKeys.currentSession)
        }
    }

    func loadCurrentSessionReadOnly() -> ProtectionSession? {
        defaults.synchronize()
        guard let data = defaults.data(forKey: SharedKeys.currentSession),
              let session = try? JSONDecoder().decode(ProtectionSession.self, from: data) else {
            return nil
        }
        return session
    }

    func loadCurrentSession() -> ProtectionSession? {
        guard let session = loadCurrentSessionReadOnly() else { return nil }
        if let end = session.scheduledEndTime, end < Date() {
            endCurrentSession(reason: .timerExpired)
            return nil
        }
        return session
    }

    func loadSessionHistory() -> [ProtectionSession] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: SharedKeys.sessionHistory),
              let history = try? JSONDecoder().decode([ProtectionSession].self, from: data) else {
            return []
        }
        return history
    }

    func addToSessionHistory(_ session: ProtectionSession) {
        var history = loadSessionHistory()
        guard !history.contains(where: { $0.id == session.id }) else { return }
        history.insert(session, at: 0)
        if let data = try? JSONEncoder().encode(Array(history.prefix(100))) {
            defaults.set(data, forKey: SharedKeys.sessionHistory)
        }
    }

    func clearSessionHistory() {
        defaults.removeObject(forKey: SharedKeys.sessionHistory)
    }

    func endCurrentSession(reason: EndReason) {
        guard var session = loadCurrentSessionReadOnly(), session.isActive else { return }
        session.blockedAttempts.append(contentsOf: drainPendingAttempts())
        session.end(reason: reason)
        addToSessionHistory(session)
        saveCurrentSession(nil)
    }

    func appendPendingAttempt(type: AttemptType, targetName: String, targetIdentifier: String,
                              outcome: AttemptOutcome = .blocked) {
        _ = withPendingAttemptsLock {
            var attempts = loadPendingAttempts()
            attempts.append(BlockedAttempt(attemptType: type, targetName: targetName,
                                           targetIdentifier: targetIdentifier, outcome: outcome))
            if let data = try? JSONEncoder().encode(attempts) {
                defaults.set(data, forKey: SharedKeys.pendingAttempts)
            }
        }
    }

    func drainPendingAttempts() -> [BlockedAttempt] {
        withPendingAttemptsLock {
            let attempts = loadPendingAttempts()
            defaults.removeObject(forKey: SharedKeys.pendingAttempts)
            return attempts
        } ?? []
    }

    private func withPendingAttemptsLock<T>(_ body: () -> T) -> T? {
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
