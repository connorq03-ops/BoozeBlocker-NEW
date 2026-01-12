import SwiftUI

struct RecentActivityCard: View {
    let sessions: [ProtectionSession]
    
    var recentSessions: [ProtectionSession] {
        Array(sessions.prefix(3))
    }
    
    var totalBlockedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions
            .filter { $0.startTime > weekAgo }
            .reduce(0) { $0 + $1.blockedAttempts.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                if totalBlockedThisWeek > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption)
                        Text("\(totalBlockedThisWeek) blocked this week")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if recentSessions.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No recent sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Session list
                VStack(spacing: 12) {
                    ForEach(recentSessions) { session in
                        RecentSessionRow(session: session)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct RecentSessionRow: View {
    let session: ProtectionSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Date indicator
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(dayNumber)
                    .font(.headline)
            }
            .frame(width: 40)
            
            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.startTime.timeString) - \(endTimeString)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.duration.shortFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Blocked count
            if !session.blockedAttempts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption)
                    Text("\(session.blockedAttempts.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.startTime).uppercased()
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: session.startTime)
    }
    
    private var endTimeString: String {
        if let endTime = session.actualEndTime {
            return endTime.timeString
        } else if let scheduledEnd = session.scheduledEndTime {
            return scheduledEnd.timeString
        } else {
            return "ongoing"
        }
    }
}

#Preview {
    RecentActivityCard(sessions: [])
        .padding()
}
