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

    func loadCurrentSession() -> ProtectionSession? {
        guard let data = defaults.data(forKey: SharedKeys.currentSession),
              let session = try? JSONDecoder().decode(ProtectionSession.self, from: data) else {
            return nil
        }
        if let end = session.scheduledEndTime, end < Date() {
            var expired = session
            expired.end(reason: .timerExpired)
            addToSessionHistory(expired)
            defaults.removeObject(forKey: SharedKeys.currentSession)
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
}
