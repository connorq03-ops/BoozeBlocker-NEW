import Foundation

/// Service for persisting user data locally
class PersistenceService {
    static let shared = PersistenceService()
    
    private let userDefaults: UserDefaults
    private let store: SharedStore
    
    // MARK: - Keys
    private enum Keys {
        static let blockedApps = "blockedApps"
    }
    
    init(defaults: UserDefaults = AppGroup.defaults, legacy: UserDefaults = .standard) {
        userDefaults = defaults
        store = SharedStore(defaults: defaults)
        if !defaults.bool(forKey: SharedKeys.migratedFromStandard) {
            for key in [SharedKeys.userSettings, SharedKeys.currentSession, SharedKeys.sessionHistory, SharedKeys.blockedContacts] {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
            defaults.set(true, forKey: SharedKeys.migratedFromStandard)
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

    // MARK: - Session History

    func addToSessionHistory(_ session: ProtectionSession) {
        store.addToSessionHistory(session)
    }

    func loadSessionHistory() -> [ProtectionSession] {
        store.loadSessionHistory()
    }

    func clearSessionHistory() {
        store.clearSessionHistory()
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
    
    // MARK: - Blocked Apps
    
    func saveBlockedApps(_ apps: [BlockedApp]) {
        if let encoded = try? JSONEncoder().encode(apps) {
            userDefaults.set(encoded, forKey: Keys.blockedApps)
        }
    }
    
    func loadBlockedApps() -> [BlockedApp] {
        guard let data = userDefaults.data(forKey: Keys.blockedApps),
              let apps = try? JSONDecoder().decode([BlockedApp].self, from: data) else {
            return []
        }
        return apps
    }
    
    // MARK: - Reset
    
    func resetAllData() {
        userDefaults.removeObject(forKey: SharedKeys.userSettings)
        userDefaults.removeObject(forKey: SharedKeys.currentSession)
        userDefaults.removeObject(forKey: SharedKeys.sessionHistory)
        userDefaults.removeObject(forKey: SharedKeys.blockedContacts)
        userDefaults.removeObject(forKey: Keys.blockedApps)
    }
}
