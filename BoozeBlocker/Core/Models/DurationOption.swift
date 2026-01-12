import Foundation

/// Predefined duration options for protection
struct DurationOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let duration: TimeInterval?
    let icon: String
    
    static let presets: [DurationOption] = [
        DurationOption(
            title: "Until 8:00 AM",
            subtitle: "Perfect for a night out",
            duration: Date.timeUntil(hour: 8),
            icon: "sunrise.fill"
        ),
        DurationOption(
            title: "4 hours",
            subtitle: "Short evening",
            duration: 4 * 60 * 60,
            icon: "clock.fill"
        ),
        DurationOption(
            title: "6 hours",
            subtitle: "Standard night",
            duration: 6 * 60 * 60,
            icon: "clock.fill"
        ),
        DurationOption(
            title: "8 hours",
            subtitle: "Long night",
            duration: 8 * 60 * 60,
            icon: "clock.fill"
        ),
        DurationOption(
            title: "Until I stop",
            subtitle: "Manual deactivation only",
            duration: nil,
            icon: "infinity"
        )
    ]
    
    var formattedEndTime: String? {
        guard let duration = duration else { return nil }
        let endDate = Date().addingTimeInterval(duration)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endDate)
    }
}
