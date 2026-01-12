import Foundation

extension Date {
    /// Returns true if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns true if this date is within the last week
    var isWithinLastWeek: Bool {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return self > weekAgo
    }
    
    /// Returns a relative description like "Today", "Yesterday", or the date
    var relativeDescription: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isWithinLastWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }
    
    /// Returns time string like "8:30 PM"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns the next occurrence of a specific hour (0-23)
    static func next(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        var target = calendar.date(from: components) ?? now
        
        // If the time has passed today, use tomorrow
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        
        return target
    }
    
    /// Returns time interval until a specific hour today or tomorrow
    static func timeUntil(hour: Int, minute: Int = 0) -> TimeInterval {
        return next(hour: hour, minute: minute).timeIntervalSinceNow
    }
}

extension TimeInterval {
    /// Format as "Xh Ym" or "Xm"
    var shortFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Format as "X hours Y minutes" or "X minutes"
    var longFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        
        if hours > 0 {
            let hourWord = hours == 1 ? "hour" : "hours"
            let minuteWord = minutes == 1 ? "minute" : "minutes"
            return "\(hours) \(hourWord) \(minutes) \(minuteWord)"
        } else {
            let minuteWord = minutes == 1 ? "minute" : "minutes"
            return "\(minutes) \(minuteWord)"
        }
    }
}
