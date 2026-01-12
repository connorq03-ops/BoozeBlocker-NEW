import WidgetKit
import SwiftUI

/// Widget entry containing protection status
struct ProtectionEntry: TimelineEntry {
    let date: Date
    let isProtected: Bool
    let timeRemaining: TimeInterval?
    let blockedAttempts: Int
}

/// Provider for widget timeline
struct ProtectionProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProtectionEntry {
        ProtectionEntry(
            date: Date(),
            isProtected: false,
            timeRemaining: nil,
            blockedAttempts: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ProtectionEntry) -> Void) {
        let entry = ProtectionEntry(
            date: Date(),
            isProtected: true,
            timeRemaining: 4 * 60 * 60,
            blockedAttempts: 3
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProtectionEntry>) -> Void) {
        // Load current session from shared UserDefaults (App Group)
        let sharedDefaults = UserDefaults(suiteName: "group.com.boozeblocker.app")
        
        var isProtected = false
        var timeRemaining: TimeInterval? = nil
        var blockedAttempts = 0
        
        if let sessionData = sharedDefaults?.data(forKey: "currentSession"),
           let session = try? JSONDecoder().decode(ProtectionSession.self, from: sessionData) {
            isProtected = session.isActive
            timeRemaining = session.timeRemaining
            blockedAttempts = session.blockedAttempts.count
        }
        
        let entry = ProtectionEntry(
            date: Date(),
            isProtected: isProtected,
            timeRemaining: timeRemaining,
            blockedAttempts: blockedAttempts
        )
        
        // Update every minute when protected, every 15 minutes when not
        let updateInterval: TimeInterval = isProtected ? 60 : 15 * 60
        let nextUpdate = Date().addingTimeInterval(updateInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

/// Small widget view
struct SmallWidgetView: View {
    let entry: ProtectionEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(entry.isProtected ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: entry.isProtected ? "shield.checkmark.fill" : "shield.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Status
            Text(entry.isProtected ? "Protected" : "Not Protected")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(entry.isProtected ? .green : .secondary)
            
            // Time remaining or blocked count
            if entry.isProtected {
                if let remaining = entry.timeRemaining {
                    Text(formatTime(remaining))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if entry.blockedAttempts > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption2)
                        Text("\(entry.blockedAttempts)")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(entry.isProtected ? Color.green.opacity(0.1) : Color.clear)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

/// Medium widget view
struct MediumWidgetView: View {
    let entry: ProtectionEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Shield
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(entry.isProtected ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: entry.isProtected ? "shield.checkmark.fill" : "shield.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                Text(entry.isProtected ? "Protected" : "Not Protected")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(entry.isProtected ? .green : .secondary)
            }
            
            // Right side - Stats
            VStack(alignment: .leading, spacing: 8) {
                if entry.isProtected {
                    if let remaining = entry.timeRemaining {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(formatTime(remaining))
                        }
                        .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                        Text("\(entry.blockedAttempts) blocked")
                    }
                    .font(.subheadline)
                } else {
                    Text("Tap to activate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Stay safe tonight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(entry.isProtected ? Color.green.opacity(0.1) : Color.clear)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes) minutes remaining"
        }
    }
}

/// Main widget definition
struct BoozeBlockerWidget: Widget {
    let kind: String = "BoozeBlockerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProtectionProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Protection Status")
        .description("See your current protection status at a glance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ProtectionEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// Quick action widget for activating protection
struct QuickActivateWidget: Widget {
    let kind: String = "QuickActivateWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProtectionProvider()) { entry in
            QuickActivateView(entry: entry)
        }
        .configurationDisplayName("Quick Activate")
        .description("Quickly activate protection")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickActivateView: View {
    let entry: ProtectionEntry
    
    var body: some View {
        VStack(spacing: 12) {
            if entry.isProtected {
                Image(systemName: "shield.checkmark.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                
                Text("Protected")
                    .font(.headline)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "shield.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("Tap to Protect")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(entry.isProtected ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .widgetURL(URL(string: "boozeblocker://activate"))
    }
}

#Preview(as: .systemSmall) {
    BoozeBlockerWidget()
} timeline: {
    ProtectionEntry(date: Date(), isProtected: false, timeRemaining: nil, blockedAttempts: 0)
    ProtectionEntry(date: Date(), isProtected: true, timeRemaining: 4 * 60 * 60, blockedAttempts: 3)
}
