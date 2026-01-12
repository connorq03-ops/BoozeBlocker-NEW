import Foundation

/// User's persistent settings for the app
struct UserSettings: Codable {
    /// Bundle identifiers of apps to block (e.g., "com.instagram.Instagram")
    var blockedAppBundleIDs: [String]
    
    /// Contact identifiers to restrict access to
    var blockedContactIDs: [String]
    
    /// Contact identifiers that are ALWAYS accessible (emergency contacts)
    var emergencyContactIDs: [String]
    
    /// Default protection duration in seconds (nil = until manual deactivation)
    var defaultDuration: TimeInterval?
    
    /// Difficulty level for sobriety tests
    var sobrietyTestDifficulty: SobrietyTestDifficulty
    
    /// Whether to show notifications when attempts are blocked
    var showBlockedAttemptNotifications: Bool
    
    /// Whether onboarding has been completed
    var hasCompletedOnboarding: Bool
    
    /// Default initializer with sensible defaults
    init(
        blockedAppBundleIDs: [String] = [],
        blockedContactIDs: [String] = [],
        emergencyContactIDs: [String] = [],
        defaultDuration: TimeInterval? = 8 * 60 * 60, // 8 hours
        sobrietyTestDifficulty: SobrietyTestDifficulty = .medium,
        showBlockedAttemptNotifications: Bool = true,
        hasCompletedOnboarding: Bool = false
    ) {
        self.blockedAppBundleIDs = blockedAppBundleIDs
        self.blockedContactIDs = blockedContactIDs
        self.emergencyContactIDs = emergencyContactIDs
        self.defaultDuration = defaultDuration
        self.sobrietyTestDifficulty = sobrietyTestDifficulty
        self.showBlockedAttemptNotifications = showBlockedAttemptNotifications
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

/// Difficulty levels for sobriety tests
enum SobrietyTestDifficulty: String, Codable, CaseIterable {
    case easy       // Simple math: 12 + 5 = ?
    case medium     // Moderate math: 47 + 38 = ?
    case hard       // Complex math: 147 + 289 = ?
    case extreme    // Typing test: Type phrase backwards
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "Simple addition (e.g., 12 + 5)"
        case .medium: return "Two-digit addition (e.g., 47 + 38)"
        case .hard: return "Three-digit addition (e.g., 147 + 289)"
        case .extreme: return "Type a phrase backwards"
        }
    }
}
