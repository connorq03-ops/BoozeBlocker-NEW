import Foundation
import UserNotifications

/// Service for managing local notifications
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Private Properties
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        // Blocked attempt notification actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ATTEMPTS",
            title: "View Attempts",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )
        
        let blockedCategory = UNNotificationCategory(
            identifier: "BLOCKED_ATTEMPT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Protection reminder actions
        let activateAction = UNNotificationAction(
            identifier: "ACTIVATE_PROTECTION",
            title: "Activate Now",
            options: .foreground
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "PROTECTION_REMINDER",
            actions: [activateAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Session ending notification
        let extendAction = UNNotificationAction(
            identifier: "EXTEND_SESSION",
            title: "Extend 2 Hours",
            options: .foreground
        )
        
        let endingCategory = UNNotificationCategory(
            identifier: "SESSION_ENDING",
            actions: [extendAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([blockedCategory, reminderCategory, endingCategory])
    }
    
    // MARK: - Notification Scheduling
    
    /// Notify when an attempt is blocked
    func notifyBlockedAttempt(type: AttemptType, targetName: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Attempt Blocked"
        content.body = "Blocked \(type.displayName.lowercased()) to \(targetName)"
        content.sound = .default
        content.categoryIdentifier = "BLOCKED_ATTEMPT"
        content.badge = NSNumber(value: 1)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        center.add(request)
    }
    
    /// Notify when protection is about to end
    func scheduleSessionEndingNotification(endTime: Date) {
        guard isAuthorized else { return }
        
        // Notify 15 minutes before end
        let warningTime = endTime.addingTimeInterval(-15 * 60)
        guard warningTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Protection Ending Soon"
        content.body = "Your protection will end in 15 minutes"
        content.sound = .default
        content.categoryIdentifier = "SESSION_ENDING"
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: warningTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "session_ending_warning",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    /// Notify when protection has ended
    func notifySessionEnded(blockedAttempts: Int) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Protection Ended"
        
        if blockedAttempts > 0 {
            content.body = "You blocked \(blockedAttempts) attempt\(blockedAttempts == 1 ? "" : "s") last night!"
        } else {
            content.body = "Great job! No blocked attempts during your session."
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "session_ended",
            content: content,
            trigger: nil
        )
        
        center.add(request)
    }
    
    /// Schedule a reminder to activate protection
    func scheduleProtectionReminder(at date: Date, message: String? = nil) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Activate Protection?"
        content.body = message ?? "Heading out? Don't forget to activate Booze Blocker!"
        content.sound = .default
        content.categoryIdentifier = "PROTECTION_REMINDER"
        
        let components = Calendar.current.dateComponents([.hour, .minute, .weekday], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "protection_reminder_\(components.weekday ?? 0)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    /// Cancel session-related notifications
    func cancelSessionNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "session_ending_warning",
            "session_ended"
        ])
    }
    
    /// Clear badge count
    func clearBadge() {
        center.setBadgeCount(0)
    }
}
