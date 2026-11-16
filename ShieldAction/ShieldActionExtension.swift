import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, token: application, name: "Blocked app", completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, token: webDomain, name: "Blocked website", completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, token: category, name: "Blocked category", completionHandler: completionHandler)
    }

    private func handle<T: Encodable>(_ action: ShieldAction, token: T, name: String,
                                      completionHandler: @escaping (ShieldActionResponse) -> Void) {
        SharedStore(defaults: AppGroup.defaults).appendPendingAttempt(
            type: .app, targetName: name, targetIdentifier: SharedStore.tokenID(token))
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = "Want access?"
            content.body = "Open Booze Blocker and pass the sobriety test."
            content.userInfo = ["url": "boozeblocker://deactivate"]
            UNUserNotificationCenter.current().add(
                .init(identifier: "shield-request", content: content, trigger: nil)) { _ in
                    completionHandler(.defer)
                }
        default:
            completionHandler(.close)
        }
    }
}
