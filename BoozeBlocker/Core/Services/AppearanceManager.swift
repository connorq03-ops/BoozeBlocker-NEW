import SwiftUI

/// Manages app-wide appearance settings
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    // MARK: - Published Properties
    
    @Published var colorScheme: ColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorSchemePreference")
        }
    }
    
    @Published var accentColor: AccentColorOption {
        didSet {
            UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColorPreference")
        }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        let schemeRaw = UserDefaults.standard.string(forKey: "colorSchemePreference") ?? "system"
        self.colorScheme = ColorSchemePreference(rawValue: schemeRaw) ?? .system
        
        let colorRaw = UserDefaults.standard.string(forKey: "accentColorPreference") ?? "blue"
        self.accentColor = AccentColorOption(rawValue: colorRaw) ?? .blue
        
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    }
    
    // MARK: - Methods
    
    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Color Scheme Preference

enum ColorSchemePreference: String, CaseIterable {
    case system
    case light
    case dark
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Accent Color Options

enum AccentColorOption: String, CaseIterable {
    case blue
    case purple
    case green
    case orange
    case pink
    case red
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .red: return .red
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    // Status colors
    static let protected = Color.green
    static let notProtected = Color.gray
    static let warning = Color.orange
    static let danger = Color.red
    
    // Background gradients
    static let protectedGradient = LinearGradient(
        colors: [Color.green.opacity(0.3), Color.blue.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let inactiveGradient = LinearGradient(
        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let shieldGradient = LinearGradient(
        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
