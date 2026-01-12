import SwiftUI

struct InsightsView: View {
    @State private var sessions: [ProtectionSession] = []
    @State private var selectedTimeRange: TimeRange = .week
    
    private let persistence = PersistenceService.shared
    
    var filteredSessions: [ProtectionSession] {
        let cutoffDate: Date
        switch selectedTimeRange {
        case .week:
            cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            cutoffDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .allTime:
            cutoffDate = Date.distantPast
        }
        return sessions.filter { $0.startTime > cutoffDate }
    }
    
    var totalSessions: Int {
        filteredSessions.count
    }
    
    var totalBlockedAttempts: Int {
        filteredSessions.reduce(0) { $0 + $1.blockedAttempts.count }
    }
    
    var totalProtectedTime: TimeInterval {
        filteredSessions.reduce(0) { $0 + $1.duration }
    }
    
    var averageSessionDuration: TimeInterval {
        guard !filteredSessions.isEmpty else { return 0 }
        return totalProtectedTime / Double(filteredSessions.count)
    }
    
    var mostBlockedApp: (name: String, count: Int)? {
        let appAttempts = filteredSessions
            .flatMap { $0.blockedAttempts }
            .filter { $0.attemptType == .app }
        
        let grouped = Dictionary(grouping: appAttempts) { $0.targetName }
        return grouped
            .map { ($0.key, $0.value.count) }
            .max { $0.1 < $1.1 }
    }
    
    var mostBlockedContact: (name: String, count: Int)? {
        let contactAttempts = filteredSessions
            .flatMap { $0.blockedAttempts }
            .filter { $0.attemptType == .message || $0.attemptType == .call }
        
        let grouped = Dictionary(grouping: contactAttempts) { $0.targetName }
        return grouped
            .map { ($0.key, $0.value.count) }
            .max { $0.1 < $1.1 }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        InsightCard(
                            title: "Sessions",
                            value: "\(totalSessions)",
                            icon: "shield.fill",
                            color: .blue
                        )
                        
                        InsightCard(
                            title: "Blocked",
                            value: "\(totalBlockedAttempts)",
                            icon: "hand.raised.fill",
                            color: .orange
                        )
                        
                        InsightCard(
                            title: "Protected Time",
                            value: totalProtectedTime.shortFormatted,
                            icon: "clock.fill",
                            color: .green
                        )
                        
                        InsightCard(
                            title: "Avg Duration",
                            value: averageSessionDuration.shortFormatted,
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Most blocked section
                    if totalBlockedAttempts > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Blocked")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                if let app = mostBlockedApp {
                                    MostBlockedRow(
                                        icon: "app.fill",
                                        title: app.name,
                                        count: app.count,
                                        color: .blue
                                    )
                                }
                                
                                if let contact = mostBlockedContact {
                                    MostBlockedRow(
                                        icon: "person.fill",
                                        title: contact.name,
                                        count: contact.count,
                                        color: .red
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Streak section
                    StreakCard(sessions: filteredSessions)
                        .padding(.horizontal)
                    
                    // Tips section
                    TipsCard()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .onAppear {
                loadSessions()
            }
        }
    }
    
    private func loadSessions() {
        sessions = persistence.loadSessionHistory()
    }
}

enum TimeRange: String, CaseIterable {
    case week
    case month
    case allTime
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .allTime: return "All Time"
        }
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct MostBlockedRow: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(count) times")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct StreakCard: View {
    let sessions: [ProtectionSession]
    
    var currentStreak: Int {
        // Calculate consecutive weeks with at least one session
        var streak = 0
        var currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        let sessionsByWeek = Dictionary(grouping: sessions) { session in
            let week = Calendar.current.component(.weekOfYear, from: session.startTime)
            let year = Calendar.current.component(.year, from: session.startTime)
            return "\(year)-\(week)"
        }
        
        while sessionsByWeek["\(currentYear)-\(currentWeek)"] != nil {
            streak += 1
            currentWeek -= 1
            if currentWeek < 1 {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Streak")
                    .font(.headline)
                Text("\(currentStreak) week\(currentStreak == 1 ? "" : "s") of protection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(currentStreak)")
                        .font(.headline)
                        .foregroundColor(.orange)
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

struct TipsCard: View {
    let tips = [
        "Set up protection before you start drinking for best results",
        "Add your ex to the block list - you'll thank yourself later",
        "Use the 'Until 8am' option for nights out",
        "Emergency contacts are always accessible, even when protected"
    ]
    
    @State private var currentTipIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Pro Tip")
                    .font(.headline)
            }
            
            Text(tips[currentTipIndex])
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.1))
        )
        .onTapGesture {
            withAnimation {
                currentTipIndex = (currentTipIndex + 1) % tips.count
            }
        }
    }
}

#Preview {
    InsightsView()
}
