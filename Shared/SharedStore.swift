import Foundation

struct SharedStore {
    let defaults: UserDefaults

    func saveCurrentSession(_ session: ProtectionSession?) {
        if let session = session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: SharedKeys.currentSession)
        } else {
            defaults.removeObject(forKey: SharedKeys.currentSession)
        }
    }

    func loadCurrentSessionReadOnly() -> ProtectionSession? {
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
        guard let data = defaults.data(forKey: SharedKeys.sessionHistory),
              let history = try? JSONDecoder().decode([ProtectionSession].self, from: data) else {
            return []
        }
        return history
    }

    func addToSessionHistory(_ session: ProtectionSession) {
        var history = loadSessionHistory()
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
        var attempts = loadPendingAttempts()
        attempts.append(BlockedAttempt(attemptType: type, targetName: targetName,
                                       targetIdentifier: targetIdentifier, outcome: outcome))
        if let data = try? JSONEncoder().encode(attempts) {
            defaults.set(data, forKey: SharedKeys.pendingAttempts)
        }
    }

    func drainPendingAttempts() -> [BlockedAttempt] {
        let attempts = loadPendingAttempts()
        defaults.removeObject(forKey: SharedKeys.pendingAttempts)
        return attempts
    }

    private func loadPendingAttempts() -> [BlockedAttempt] {
        guard let data = defaults.data(forKey: SharedKeys.pendingAttempts),
              let attempts = try? JSONDecoder().decode([BlockedAttempt].self, from: data) else { return [] }
        return attempts
    }
}
