import Foundation

/// Represents a single protection session (from activation to deactivation)
struct ProtectionSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    
    /// When protection is scheduled to end (nil = manual deactivation only)
    let scheduledEndTime: Date?
    
    /// When protection actually ended (nil = still active)
    var actualEndTime: Date?
    
    /// How the session was activated
    let activationType: ActivationType
    
    /// How the session ended (nil = still active)
    var endReason: EndReason?
    
    /// All blocked attempts during this session
    var blockedAttempts: [BlockedAttempt]
    
    /// Whether this session is currently active
    var isActive: Bool {
        return actualEndTime == nil
    }
    
    /// Duration of the session (or time elapsed if still active)
    var duration: TimeInterval {
        let endTime = actualEndTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Time remaining until scheduled end (nil if no scheduled end or already ended)
    var timeRemaining: TimeInterval? {
        guard isActive, let scheduledEnd = scheduledEndTime else { return nil }
        let remaining = scheduledEnd.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }
    
    /// Initialize a new active session
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        scheduledEndTime: Date? = nil,
        activationType: ActivationType = .manual
    ) {
        self.id = id
        self.startTime = startTime
        self.scheduledEndTime = scheduledEndTime
        self.actualEndTime = nil
        self.activationType = activationType
        self.endReason = nil
        self.blockedAttempts = []
    }
    
    /// End the session with a reason
    mutating func end(reason: EndReason) {
        self.actualEndTime = Date()
        self.endReason = reason
    }
    
    /// Add a blocked attempt to this session
    mutating func addBlockedAttempt(_ attempt: BlockedAttempt) {
        self.blockedAttempts.append(attempt)
    }
}

/// How the protection session was activated
enum ActivationType: String, Codable {
    case manual         // User tapped "Activate Protection"
    case scheduled      // Pre-scheduled time (e.g., every Friday 8pm)
    case location       // Triggered by entering a location (bar, club)
    case ouraDetected   // Oura ring detected drinking (v2.0)
    case creditCard     // Credit card charge at bar (v2.0)
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .scheduled: return "Scheduled"
        case .location: return "Location"
        case .ouraDetected: return "Oura Ring"
        case .creditCard: return "Credit Card"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "hand.tap"
        case .scheduled: return "calendar"
        case .location: return "location.fill"
        case .ouraDetected: return "heart.circle"
        case .creditCard: return "creditcard"
        }
    }
}

/// How the protection session ended
enum EndReason: String, Codable {
    case timerExpired       // Scheduled end time reached
    case sobrietyTestPassed // User passed the sobriety test
    case emergencyOverride  // User used emergency override
    case manualStop         // User stopped without test (if allowed)
    
    var displayName: String {
        switch self {
        case .timerExpired: return "Timer Expired"
        case .sobrietyTestPassed: return "Sobriety Test Passed"
        case .emergencyOverride: return "Emergency Override"
        case .manualStop: return "Manual Stop"
        }
    }
}
