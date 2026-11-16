import Foundation
import Combine
import WidgetKit

/// Central manager for protection state and blocking logic
@MainActor
final class ProtectionManager: ObservableObject {
    static let shared = ProtectionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentSession: ProtectionSession?
    @Published private(set) var isProtectionActive: Bool = false
    @Published private(set) var timeRemaining: TimeInterval?
    @Published private(set) var blockingWarning: String?
    @Published private(set) var sobrietyCooldownRemaining: TimeInterval = 0
    @Published private(set) var failedSobrietyAttempts = 0
    @Published var showSobrietyTest = false
    @Published var showDurationPicker = false
    
    // MARK: - Private Properties
    
    private let persistence: PersistenceService
    private let notifications: NotificationService
    private let blocker: BlockingController
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(persistence: PersistenceService = .shared, notifications: NotificationService = .shared,
         blocker: BlockingController? = nil) {
        self.persistence = persistence
        self.notifications = notifications
        self.blocker = blocker ?? ScreenTimeService.shared
        reconcile()
    }
    
    // MARK: - Public Methods
    
    /// Activate protection with optional duration
    /// - Parameter duration: Duration in seconds, nil for manual deactivation only
    func activateProtection(duration: TimeInterval? = nil, type: ActivationType = .manual) {
        guard !isProtectionActive, duration.map({ $0.isFinite && $0 > 0 }) ?? true else { return }
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
        
        applyBlocking()
        
        NotificationCenter.default.post(name: .protectionActivated, object: nil)
    }
    
    /// Deactivate protection with a reason
    func deactivateProtection(reason: EndReason) {
        blocker.stopBlocking()
        guard var session = currentSession else { return }
        session.blockedAttempts.append(contentsOf: persistence.drainPendingAttempts())
        
        session.end(reason: reason)
        persistence.addToSessionHistory(session)
        persistence.saveCurrentSession(nil)
        
        currentSession = nil
        isProtectionActive = false
        timeRemaining = nil
        blockingWarning = nil
        showSobrietyTest = false
        resetSobrietyFailures()
        
        stopTimer()
        notifications.cancelSessionNotifications()
        notifications.notifySessionEnded(blockedAttempts: session.blockedAttempts.count)
        WidgetCenter.shared.reloadAllTimelines()
        
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
        applyBlocking()
        updateTimeRemaining()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reconcile() {
        refreshSobrietyCooldown()
        ingestPendingAttempts()
        loadCurrentSession()
        do {
            try blocker.reconcile(sessionActive: isProtectionActive, endDate: currentSession?.scheduledEndTime)
            updateBlockingWarning()
        } catch {
            blockingWarning = "Apps may not unblock automatically: \(error.localizedDescription)"
        }
        if isProtectionActive {
            startTimerIfNeeded()
        } else {
            stopTimer()
            showSobrietyTest = false
            blockingWarning = nil
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func ingestPendingAttempts() {
        guard var session = persistence.loadCurrentSession() else { return }
        session.blockedAttempts.append(contentsOf: persistence.drainPendingAttempts())
        persistence.saveCurrentSession(session)
        currentSession = session
    }

    func handleDeepLink(_ action: DeepLinkAction) {
        switch action {
        case .activate(let duration):
            guard !isProtectionActive else { return }
            if let duration { activateProtection(duration: duration) }
            else { showDurationPicker = true }
        case .deactivate:
            requestSobrietyTest()
        case .openSettings, .openHistory:
            break
        }
    }

    func requestSobrietyTest() {
        refreshSobrietyCooldown()
        guard isProtectionActive, sobrietyCooldownRemaining == 0 else { return }
        showDurationPicker = false
        showSobrietyTest = true
    }

    func recordSobrietyFailure(now: Date = Date()) {
        refreshSobrietyCooldown(now: now)
        guard sobrietyCooldownRemaining == 0 else { return }
        failedSobrietyAttempts += 1
        persistence.saveSobrietyFailures(failedSobrietyAttempts)
        if failedSobrietyAttempts >= 3 {
            persistence.saveSobrietyCooldown(now.addingTimeInterval(10 * 60))
            refreshSobrietyCooldown(now: now)
        }
    }

    func refreshSobrietyCooldown(now: Date = Date()) {
        failedSobrietyAttempts = persistence.loadSobrietyFailures()
        if let until = persistence.loadSobrietyCooldown() {
            sobrietyCooldownRemaining = max(0, until.timeIntervalSince(now))
            if sobrietyCooldownRemaining == 0 { resetSobrietyFailures() }
        } else {
            sobrietyCooldownRemaining = 0
        }
    }

    var sobrietyTestButtonTitle: String {
        guard sobrietyCooldownRemaining > 0 else { return "Take Sobriety Test" }
        let seconds = Int(ceil(sobrietyCooldownRemaining))
        return String(format: "Take Sobriety Test (%d:%02d)", seconds / 60, seconds % 60)
    }

    private func resetSobrietyFailures() {
        persistence.saveSobrietyFailures(0)
        persistence.saveSobrietyCooldown(nil)
        failedSobrietyAttempts = 0
        sobrietyCooldownRemaining = 0
    }

    private func applyBlocking() {
        do {
            try blocker.startBlocking(until: currentSession?.scheduledEndTime)
            updateBlockingWarning()
        } catch {
            blockingWarning = "Apps may not unblock automatically: \(error.localizedDescription)"
        }
    }

    private func updateBlockingWarning() {
        if !blocker.isAuthorized {
            blockingWarning = "Screen Time access is unavailable — apps are not being blocked."
        } else if !blocker.hasSelection {
            blockingWarning = "No apps selected — nothing is being blocked."
        } else if let error = (blocker as? ScreenTimeService)?.lastError {
            blockingWarning = error
        } else {
            blockingWarning = nil
        }
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
            Task { @MainActor in self?.timerTick() }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerTick() {
        refreshSobrietyCooldown()
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
