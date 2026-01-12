import SwiftUI

struct HistoryView: View {
    @State private var sessions: [ProtectionSession] = []
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .navigationTitle("History")
            .onAppear {
                loadSessions()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Protection History")
                .font(.headline)
            
            Text("Your past protection sessions will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var sessionsList: some View {
        List {
            // Stats Summary
            Section {
                HStack {
                    StatCard(
                        title: "Total Sessions",
                        value: "\(sessions.count)",
                        icon: "shield.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Attempts Blocked",
                        value: "\(totalBlockedAttempts)",
                        icon: "hand.raised.fill",
                        color: .green
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Sessions List
            Section {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRow(session: session)
                    }
                }
            } header: {
                Text("Past Sessions")
            }
        }
    }
    
    private var totalBlockedAttempts: Int {
        sessions.reduce(0) { $0 + $1.blockedAttempts.count }
    }
    
    private func loadSessions() {
        sessions = persistence.loadSessionHistory()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SessionRow: View {
    let session: ProtectionSession
    
    var body: some View {
        HStack {
            // Status icon
            ZStack {
                Circle()
                    .fill(session.isActive ? Color.green : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: session.activationType.icon)
                    .foregroundColor(session.isActive ? .white : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startTime, style: .date)
                    .fontWeight(.medium)
                
                HStack {
                    Text(session.startTime, style: .time)
                    Text("•")
                    Text(formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Blocked attempts badge
            if !session.blockedAttempts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption)
                    Text("\(session.blockedAttempts.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
        }
    }
    
    private var formattedDuration: String {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct SessionDetailView: View {
    let session: ProtectionSession
    
    var body: some View {
        List {
            // Session Info
            Section {
                LabeledContent("Started") {
                    Text(session.startTime, format: .dateTime)
                }
                
                if let endTime = session.actualEndTime {
                    LabeledContent("Ended") {
                        Text(endTime, format: .dateTime)
                    }
                }
                
                LabeledContent("Duration") {
                    Text(formattedDuration)
                }
                
                LabeledContent("Activation") {
                    Label(session.activationType.displayName, systemImage: session.activationType.icon)
                }
                
                if let reason = session.endReason {
                    LabeledContent("End Reason") {
                        Text(reason.displayName)
                    }
                }
            } header: {
                Text("Session Details")
            }
            
            // Blocked Attempts
            Section {
                if session.blockedAttempts.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No blocked attempts")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(session.blockedAttempts) { attempt in
                        HStack {
                            Image(systemName: attempt.attemptType.icon)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text(attempt.targetName)
                                    .fontWeight(.medium)
                                Text(attempt.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(attempt.outcome.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(outcomeColor(attempt.outcome).opacity(0.1))
                                .foregroundColor(outcomeColor(attempt.outcome))
                                .cornerRadius(8)
                        }
                    }
                }
            } header: {
                Text("Blocked Attempts (\(session.blockedAttempts.count))")
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var formattedDuration: String {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hours \(minutes) minutes"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func outcomeColor(_ outcome: AttemptOutcome) -> Color {
        switch outcome {
        case .blocked: return .green
        case .allowedAfterTest: return .yellow
        case .emergencyOverride: return .red
        }
    }
}

#Preview {
    HistoryView()
}
