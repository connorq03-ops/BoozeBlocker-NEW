import Foundation

/// User's persistent settings for the app
struct UserSettings: Codable, Equatable {
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
    
    /// Default initializer with sensible defaults
    init(
        blockedAppBundleIDs: [String] = [],
        blockedContactIDs: [String] = [],
        emergencyContactIDs: [String] = [],
        defaultDuration: TimeInterval? = 8 * 60 * 60, // 8 hours
        sobrietyTestDifficulty: SobrietyTestDifficulty = .medium,
        showBlockedAttemptNotifications: Bool = true
    ) {
        self.blockedAppBundleIDs = blockedAppBundleIDs
        self.blockedContactIDs = blockedContactIDs
        self.emergencyContactIDs = emergencyContactIDs
        self.defaultDuration = defaultDuration
        self.sobrietyTestDifficulty = sobrietyTestDifficulty
        self.showBlockedAttemptNotifications = showBlockedAttemptNotifications
    }
    private enum CodingKeys: String, CodingKey {
        case blockedAppBundleIDs, blockedContactIDs, emergencyContactIDs, defaultDuration
        case sobrietyTestDifficulty, showBlockedAttemptNotifications
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserSettings()
        blockedAppBundleIDs = try values.decodeIfPresent([String].self, forKey: .blockedAppBundleIDs) ?? defaults.blockedAppBundleIDs
        blockedContactIDs = try values.decodeIfPresent([String].self, forKey: .blockedContactIDs) ?? defaults.blockedContactIDs
        emergencyContactIDs = try values.decodeIfPresent([String].self, forKey: .emergencyContactIDs) ?? defaults.emergencyContactIDs
        defaultDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .defaultDuration)
        sobrietyTestDifficulty = try values.decodeIfPresent(SobrietyTestDifficulty.self, forKey: .sobrietyTestDifficulty) ?? defaults.sobrietyTestDifficulty
        showBlockedAttemptNotifications = try values.decodeIfPresent(Bool.self, forKey: .showBlockedAttemptNotifications) ?? defaults.showBlockedAttemptNotifications
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(blockedAppBundleIDs, forKey: .blockedAppBundleIDs)
        try values.encode(blockedContactIDs, forKey: .blockedContactIDs)
        try values.encode(emergencyContactIDs, forKey: .emergencyContactIDs)
        try values.encode(defaultDuration, forKey: .defaultDuration)
        try values.encode(sobrietyTestDifficulty, forKey: .sobrietyTestDifficulty)
        try values.encode(showBlockedAttemptNotifications, forKey: .showBlockedAttemptNotifications)
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
