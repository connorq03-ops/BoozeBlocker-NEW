import Foundation
import UserNotifications

enum SessionEndedNotification {
    static func request(blockedAttempts: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Protection Ended"
        if blockedAttempts > 0 {
            content.body = "You blocked \(blockedAttempts) attempt\(blockedAttempts == 1 ? "" : "s") last night!"
        } else {
            content.body = "Great job! No blocked attempts during your session."
        }
        content.sound = .default
        return UNNotificationRequest(identifier: "session_ended", content: content, trigger: nil)
    }

    static func endSession(in store: SharedStore,
                           post: (UNNotificationRequest) -> Void = { UNUserNotificationCenter.current().add($0) }) {
        guard let session = store.endCurrentSession(reason: .timerExpired) else { return }
        post(request(blockedAttempts: session.blockedAttempts.count))
    }
}
