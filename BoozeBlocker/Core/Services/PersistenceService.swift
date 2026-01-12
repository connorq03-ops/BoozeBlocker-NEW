import Foundation

/// Service for persisting user data locally
class PersistenceService {
    static let shared = PersistenceService()
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let userSettings = "userSettings"
        static let currentSession = "currentSession"
        static let sessionHistory = "sessionHistory"
        static let blockedContacts = "blockedContacts"
        static let blockedApps = "blockedApps"
    }
    
    private init() {}
    
    // MARK: - User Settings
    
    func saveUserSettings(_ settings: UserSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: Keys.userSettings)
        }
    }
    
    func loadUserSettings() -> UserSettings {
        guard let data = userDefaults.data(forKey: Keys.userSettings),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }
    
    // MARK: - Current Session
    
    func saveCurrentSession(_ session: ProtectionSession?) {
        if let session = session,
           let encoded = try? JSONEncoder().encode(session) {
            userDefaults.set(encoded, forKey: Keys.currentSession)
        } else {
            userDefaults.removeObject(forKey: Keys.currentSession)
        }
    }
    
    func loadCurrentSession() -> ProtectionSession? {
        guard let data = userDefaults.data(forKey: Keys.currentSession),
              let session = try? JSONDecoder().decode(ProtectionSession.self, from: data) else {
            return nil
        }
        
        // Check if session should have expired
        if let scheduledEnd = session.scheduledEndTime, scheduledEnd < Date() {
            // Session expired, end it
            var expiredSession = session
            expiredSession.end(reason: .timerExpired)
            addToSessionHistory(expiredSession)
            userDefaults.removeObject(forKey: Keys.currentSession)
            return nil
        }
        
        return session
    }
    
    // MARK: - Session History
    
    func addToSessionHistory(_ session: ProtectionSession) {
        var history = loadSessionHistory()
        history.insert(session, at: 0)
        
        // Keep only last 100 sessions
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: Keys.sessionHistory)
        }
    }
    
    func loadSessionHistory() -> [ProtectionSession] {
        guard let data = userDefaults.data(forKey: Keys.sessionHistory),
              let history = try? JSONDecoder().decode([ProtectionSession].self, from: data) else {
            return []
        }
        return history
    }
    
    func clearSessionHistory() {
        userDefaults.removeObject(forKey: Keys.sessionHistory)
    }
    
    // MARK: - Blocked Contacts
    
    func saveBlockedContacts(_ contacts: [BlockedContact]) {
        if let encoded = try? JSONEncoder().encode(contacts) {
            userDefaults.set(encoded, forKey: Keys.blockedContacts)
        }
    }
    
    func loadBlockedContacts() -> [BlockedContact] {
        guard let data = userDefaults.data(forKey: Keys.blockedContacts),
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
        userDefaults.removeObject(forKey: Keys.userSettings)
        userDefaults.removeObject(forKey: Keys.currentSession)
        userDefaults.removeObject(forKey: Keys.sessionHistory)
        userDefaults.removeObject(forKey: Keys.blockedContacts)
        userDefaults.removeObject(forKey: Keys.blockedApps)
    }
}
