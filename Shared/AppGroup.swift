import Foundation

enum AppGroup {
    static let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "group.com.connorq03.boozeblocker"
    static let defaults = UserDefaults(suiteName: id)!
}

enum SharedKeys {
    static let currentSession = "currentSession"
    static let sessionHistory = "sessionHistory"
    static let userSettings = "userSettings"
    static let blockedContacts = "blockedContacts"
    static let activitySelection = "familyActivitySelection"
    static let pendingAttempts = "pendingBlockedAttempts"
    static let migratedFromStandard = "migratedFromStandardV1"
}
