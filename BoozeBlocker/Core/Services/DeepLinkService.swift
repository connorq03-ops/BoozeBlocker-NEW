import Foundation

/// Service for handling deep links and URL schemes
class DeepLinkService: ObservableObject {
    static let shared = DeepLinkService()
    
    @Published var pendingAction: DeepLinkAction?
    
    private init() {}
    
    /// Handle incoming URL
    func handle(url: URL) -> Bool {
        guard url.scheme == "boozeblocker" else { return false }
        
        switch url.host {
        case "activate":
            pendingAction = .activate(duration: parseDuration(from: url))
            return true
            
        case "deactivate":
            pendingAction = .deactivate
            return true
            
        case "settings":
            pendingAction = .openSettings(section: url.pathComponents.last)
            return true
            
        case "history":
            pendingAction = .openHistory
            return true
            
        default:
            return false
        }
    }
    
    /// Clear pending action after handling
    func clearPendingAction() {
        pendingAction = nil
    }
    
    private func parseDuration(from url: URL) -> TimeInterval? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let durationString = components.queryItems?.first(where: { $0.name == "duration" })?.value,
              let duration = TimeInterval(durationString) else {
            return nil
        }
        return duration
    }
}

/// Actions that can be triggered via deep link
enum DeepLinkAction {
    case activate(duration: TimeInterval?)
    case deactivate
    case openSettings(section: String?)
    case openHistory
}

/// URL scheme examples:
/// - boozeblocker://activate - Open app and show activation
/// - boozeblocker://activate?duration=14400 - Activate for 4 hours
/// - boozeblocker://deactivate - Show deactivation flow
/// - boozeblocker://settings - Open settings
/// - boozeblocker://settings/apps - Open blocked apps settings
/// - boozeblocker://history - Open history view
