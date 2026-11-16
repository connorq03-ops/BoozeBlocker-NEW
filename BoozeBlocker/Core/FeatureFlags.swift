import Foundation

enum FeatureFlags: String, CaseIterable {
    case integrations, siriShortcuts, delayedMessages, schedules, extraSobrietyTests, morningSummary

    func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: "feature.\(rawValue)")
        #else
        return false
        #endif
    }

    static var integrationsEnabled: Bool { integrations.isEnabled() }
    static var siriShortcutsEnabled: Bool { siriShortcuts.isEnabled() }
    static var delayedMessagesEnabled: Bool { delayedMessages.isEnabled() }
    static var schedulesEnabled: Bool { schedules.isEnabled() }
    static var morningSummaryEnabled: Bool { morningSummary.isEnabled() }
}
