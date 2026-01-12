import Foundation

/// Represents a single blocked attempt during a protection session
struct BlockedAttempt: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    
    /// Type of action that was blocked
    let attemptType: AttemptType
    
    /// Name of the target (app name or contact name)
    let targetName: String
    
    /// Identifier of the target (bundle ID or contact ID)
    let targetIdentifier: String
    
    /// What happened with this attempt
    let outcome: AttemptOutcome
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        attemptType: AttemptType,
        targetName: String,
        targetIdentifier: String,
        outcome: AttemptOutcome = .blocked
    ) {
        self.id = id
        self.timestamp = timestamp
        self.attemptType = attemptType
        self.targetName = targetName
        self.targetIdentifier = targetIdentifier
        self.outcome = outcome
    }
}

/// Type of blocked attempt
enum AttemptType: String, Codable {
    case app        // Tried to open a blocked app
    case message    // Tried to message a blocked contact
    case call       // Tried to call a blocked contact
    
    var displayName: String {
        switch self {
        case .app: return "App"
        case .message: return "Message"
        case .call: return "Call"
        }
    }
    
    var icon: String {
        switch self {
        case .app: return "app.fill"
        case .message: return "message.fill"
        case .call: return "phone.fill"
        }
    }
}

/// Outcome of a blocked attempt
enum AttemptOutcome: String, Codable {
    case blocked            // Successfully blocked
    case allowedAfterTest   // User passed sobriety test, allowed through
    case emergencyOverride  // User used emergency override
    
    var displayName: String {
        switch self {
        case .blocked: return "Blocked"
        case .allowedAfterTest: return "Allowed (Test Passed)"
        case .emergencyOverride: return "Emergency Override"
        }
    }
    
    var color: String {
        switch self {
        case .blocked: return "green"
        case .allowedAfterTest: return "yellow"
        case .emergencyOverride: return "red"
        }
    }
}
