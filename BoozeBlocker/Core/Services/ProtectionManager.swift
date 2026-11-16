import Foundation
import Combine
import WidgetKit

/// Central manager for protection state and blocking logic
class ProtectionManager: ObservableObject {
    static let shared = ProtectionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentSession: ProtectionSession?
    @Published private(set) var isProtectionActive: Bool = false
    @Published private(set) var timeRemaining: TimeInterval?
    
    // MARK: - Private Properties
    
    private let persistence: PersistenceService
    private let notifications: NotificationService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(persistence: PersistenceService = .shared, notifications: NotificationService = .shared) {
        self.persistence = persistence
        self.notifications = notifications
        loadCurrentSession()
        startTimerIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Activate protection with optional duration
    /// - Parameter duration: Duration in seconds, nil for manual deactivation only
    func activateProtection(duration: TimeInterval? = nil, type: ActivationType = .manual) {
        guard !isProtectionActive else { return }

        let scheduledEnd: Date? = duration.map { Date().addingTimeInterval($0) }
        
        let session = ProtectionSession(
            startTime: Date(),
            scheduledEndTime: scheduledEnd,
            activationType: type
        )
        
        currentSession = session
        isProtectionActive = true
        
        persistence.saveCurrentSession(session)
        updateTimeRemaining()
        startTimerIfNeeded()
        if let end = session.scheduledEndTime {
            notifications.scheduleSessionEndingNotification(endTime: end)
        }
        WidgetCenter.shared.reloadAllTimelines()
        
        // TODO: Activate Screen Time restrictions
        // TODO: Activate Focus Mode for contacts
        
        NotificationCenter.default.post(name: .protectionActivated, object: nil)
    }
    
    /// Deactivate protection with a reason
    func deactivateProtection(reason: EndReason) {
        guard var session = currentSession else { return }
        
        session.end(reason: reason)
        persistence.addToSessionHistory(session)
        persistence.saveCurrentSession(nil)
        
        currentSession = nil
        isProtectionActive = false
        timeRemaining = nil
        
        stopTimer()
        notifications.cancelSessionNotifications()
        notifications.notifySessionEnded(blockedAttempts: session.blockedAttempts.count)
        WidgetCenter.shared.reloadAllTimelines()
        
        // TODO: Deactivate Screen Time restrictions
        // TODO: Deactivate Focus Mode
        
        NotificationCenter.default.post(name: .protectionDeactivated, object: nil)
    }
    
    /// Record a blocked attempt
    func recordBlockedAttempt(type: AttemptType, targetName: String, targetIdentifier: String, outcome: AttemptOutcome = .blocked) {
        guard var session = currentSession else { return }
        
        let attempt = BlockedAttempt(
            attemptType: type,
            targetName: targetName,
            targetIdentifier: targetIdentifier,
            outcome: outcome
        )
        
        session.addBlockedAttempt(attempt)
        currentSession = session
        persistence.saveCurrentSession(session)
        
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .attemptBlocked, object: attempt)
    }
    
    func extendSession(by interval: TimeInterval) {
        guard var session = currentSession, session.isActive,
              let end = session.scheduledEndTime else { return }
        session.scheduledEndTime = end.addingTimeInterval(interval)
        currentSession = session
        persistence.saveCurrentSession(session)
        notifications.scheduleSessionEndingNotification(endTime: end.addingTimeInterval(interval))
        updateTimeRemaining()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Check if a specific app is currently blocked
    func isAppBlocked(bundleIdentifier: String) -> Bool {
        guard isProtectionActive else { return false }
        let settings = persistence.loadUserSettings()
        return settings.blockedAppBundleIDs.contains(bundleIdentifier)
    }
    
    /// Check if a specific contact is currently blocked
    func isContactBlocked(contactIdentifier: String) -> Bool {
        guard isProtectionActive else { return false }
        let settings = persistence.loadUserSettings()
        
        // Emergency contacts are never blocked
        if settings.emergencyContactIDs.contains(contactIdentifier) {
            return false
        }
        
        return settings.blockedContactIDs.contains(contactIdentifier)
    }
    
    /// Get formatted time remaining string
    func formattedTimeRemaining() -> String {
        guard let remaining = timeRemaining, remaining > 0 else {
            return "Until you stop"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentSession() {
        currentSession = persistence.loadCurrentSession()
        isProtectionActive = currentSession?.isActive ?? false
        updateTimeRemaining()
    }
    
    private func startTimerIfNeeded() {
        guard isProtectionActive else { return }
        
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerTick() {
        updateTimeRemaining()
        
        // Check if timer expired
        if let remaining = timeRemaining, remaining <= 0 {
            deactivateProtection(reason: .timerExpired)
        }
    }
    
    private func updateTimeRemaining() {
        timeRemaining = currentSession?.timeRemaining
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let protectionActivated = Notification.Name("protectionActivated")
    static let protectionDeactivated = Notification.Name("protectionDeactivated")
    static let attemptBlocked = Notification.Name("attemptBlocked")
}
