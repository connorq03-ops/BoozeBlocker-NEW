import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case "ACTIVATE_PROTECTION":
                _ = DeepLinkService.shared.handle(url: URL(string: "boozeblocker://activate")!)
            case "VIEW_ATTEMPTS":
                _ = DeepLinkService.shared.handle(url: URL(string: "boozeblocker://history")!)
            case "EXTEND_SESSION":
                ProtectionManager.shared.extendSession(by: 2 * 3600)
            case UNNotificationDefaultActionIdentifier:
                if let value = response.notification.request.content.userInfo["url"] as? String,
                   let url = URL(string: value) {
                    _ = DeepLinkService.shared.handle(url: url)
                }
            default:
                break
            }
            completionHandler()
        }
    }
}
