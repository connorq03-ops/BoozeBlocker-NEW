import Foundation

/// Service for persisting user data locally
class PersistenceService {
    static let shared = PersistenceService()
    
    private let userDefaults: UserDefaults
    private let legacyDefaults: UserDefaults
    private let store: SharedStore
    
    init(defaults: UserDefaults = AppGroup.defaults, legacy: UserDefaults = .standard) {
        userDefaults = defaults
        legacyDefaults = legacy
        store = SharedStore(defaults: defaults)
        if !defaults.bool(forKey: SharedKeys.migratedFromStandard) {
            for key in [SharedKeys.userSettings, SharedKeys.currentSession, SharedKeys.sessionHistory, SharedKeys.blockedContacts] {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
            defaults.set(true, forKey: SharedKeys.migratedFromStandard)
        }
        for key in ["blockedApps", "screenTimeAuthorized"] {
            defaults.removeObject(forKey: key)
            legacy.removeObject(forKey: key)
        }
    }
    
    // MARK: - User Settings
    
    func saveUserSettings(_ settings: UserSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: SharedKeys.userSettings)
        }
    }
    
    func loadUserSettings() -> UserSettings {
        guard let data = userDefaults.data(forKey: SharedKeys.userSettings),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }
    
    // MARK: - Current Session
    
    func saveCurrentSession(_ session: ProtectionSession?) {
        store.saveCurrentSession(session)
    }

    func loadCurrentSession() -> ProtectionSession? {
        store.loadCurrentSession()
    }

    func loadCurrentSessionReadOnly() -> ProtectionSession? {
        store.loadCurrentSessionReadOnly()
    }

    func ingestPendingAttempts() -> ProtectionSession? {
        store.ingestPendingAttempts()
    }

    func endCurrentSession(reason: EndReason, expectedSessionID: UUID) -> ProtectionSession? {
        store.endCurrentSession(reason: reason, expectedSessionID: expectedSessionID)
    }

    func updateCurrentSession(id: UUID, _ update: (inout ProtectionSession) -> Void) -> ProtectionSession? {
        store.updateCurrentSession(id: id, update)
    }

    // MARK: - Session History

    func addToSessionHistory(_ session: ProtectionSession) {
        store.addToSessionHistory(session)
    }

    func loadSessionHistory() -> [ProtectionSession] {
        store.loadSessionHistory()
    }

    func clearSessionHistory() {
        store.clearSessionHistory()
        legacyDefaults.removeObject(forKey: SharedKeys.sessionHistory)
    }

    // MARK: - Blocked Contacts
    
    func saveBlockedContacts(_ contacts: [BlockedContact]) {
        if let encoded = try? JSONEncoder().encode(contacts) {
            userDefaults.set(encoded, forKey: SharedKeys.blockedContacts)
        }
    }
    
    func loadBlockedContacts() -> [BlockedContact] {
        guard let data = userDefaults.data(forKey: SharedKeys.blockedContacts),
              let contacts = try? JSONDecoder().decode([BlockedContact].self, from: data) else {
            return []
        }
        return contacts
    }
    
    func drainPendingAttempts() -> [BlockedAttempt] {
        store.drainPendingAttempts()
    }

    func loadSobrietyFailures() -> Int { userDefaults.integer(forKey: "sobrietyFailures") }
    func saveSobrietyFailures(_ count: Int) { userDefaults.set(count, forKey: "sobrietyFailures") }
    func loadSobrietyCooldown() -> Date? { userDefaults.object(forKey: "sobrietyCooldownUntil") as? Date }
    func saveSobrietyCooldown(_ date: Date?) { userDefaults.set(date, forKey: "sobrietyCooldownUntil") }
    
    // MARK: - Reset
    
    func resetAllData() {
        for key in [SharedKeys.userSettings, SharedKeys.currentSession, SharedKeys.sessionHistory, SharedKeys.blockedContacts,
                    SharedKeys.activitySelection, SharedKeys.pendingAttempts, "sobrietyFailures", "sobrietyCooldownUntil",
                    "blockedApps", "screenTimeAuthorized"] {
            userDefaults.removeObject(forKey: key)
            legacyDefaults.removeObject(forKey: key)
        }
    }
}
