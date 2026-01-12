import Foundation

/// Represents an app that can be blocked
struct BlockedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    
    /// The app's bundle identifier (e.g., "com.instagram.Instagram")
    let bundleIdentifier: String
    
    /// Display name of the app
    let displayName: String
    
    /// Whether this app is currently in the block list
    var isBlocked: Bool
    
    init(bundleIdentifier: String, displayName: String, isBlocked: Bool = false) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.isBlocked = isBlocked
    }
}

/// Common apps that users might want to block
extension BlockedApp {
    static let commonApps: [BlockedApp] = [
        // Social Media
        BlockedApp(bundleIdentifier: "com.burbn.instagram", displayName: "Instagram"),
        BlockedApp(bundleIdentifier: "com.facebook.Facebook", displayName: "Facebook"),
        BlockedApp(bundleIdentifier: "com.atebits.Tweetie2", displayName: "Twitter/X"),
        BlockedApp(bundleIdentifier: "com.zhiliaoapp.musically", displayName: "TikTok"),
        BlockedApp(bundleIdentifier: "com.snapchat.snapchat", displayName: "Snapchat"),
        BlockedApp(bundleIdentifier: "com.linkedin.LinkedIn", displayName: "LinkedIn"),
        
        // Dating
        BlockedApp(bundleIdentifier: "com.cardify.tinder", displayName: "Tinder"),
        BlockedApp(bundleIdentifier: "com.bumble.app", displayName: "Bumble"),
        BlockedApp(bundleIdentifier: "com.hinge.Hinge", displayName: "Hinge"),
        
        // Messaging
        BlockedApp(bundleIdentifier: "com.apple.MobileSMS", displayName: "Messages"),
        BlockedApp(bundleIdentifier: "net.whatsapp.WhatsApp", displayName: "WhatsApp"),
        BlockedApp(bundleIdentifier: "com.facebook.Messenger", displayName: "Messenger"),
        BlockedApp(bundleIdentifier: "org.telegram.Telegram", displayName: "Telegram"),
        BlockedApp(bundleIdentifier: "com.discord.Discord", displayName: "Discord"),
        BlockedApp(bundleIdentifier: "com.slack.Slack", displayName: "Slack"),
        
        // Communication
        BlockedApp(bundleIdentifier: "com.apple.mobilephone", displayName: "Phone"),
        BlockedApp(bundleIdentifier: "com.apple.facetime", displayName: "FaceTime"),
        
        // Email
        BlockedApp(bundleIdentifier: "com.apple.mobilemail", displayName: "Mail"),
        BlockedApp(bundleIdentifier: "com.google.Gmail", displayName: "Gmail"),
        
        // Shopping
        BlockedApp(bundleIdentifier: "com.amazon.Amazon", displayName: "Amazon"),
        BlockedApp(bundleIdentifier: "com.ebay.iphone", displayName: "eBay"),
        
        // Finance
        BlockedApp(bundleIdentifier: "com.venmo.Venmo", displayName: "Venmo"),
        BlockedApp(bundleIdentifier: "com.squareup.cashapp", displayName: "Cash App"),
        BlockedApp(bundleIdentifier: "com.paypal.PPClient", displayName: "PayPal"),
    ]
}
