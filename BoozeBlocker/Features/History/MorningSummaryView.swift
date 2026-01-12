import SwiftUI

/// Morning-after summary view showing what happened during protection
struct MorningSummaryView: View {
    let session: ProtectionSession
    let onDismiss: () -> Void
    
    @State private var showDetails = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Stats cards
                    statsSection
                    
                    // Blocked attempts
                    if !session.blockedAttempts.isEmpty {
                        blockedAttemptsSection
                    }
                    
                    // Encouragement
                    encouragementSection
                    
                    // Share button
                    shareSection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Good Morning!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Sun icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            
            Text("Your Night in Review")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(session.startTime, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            SummaryStatCard(
                icon: "clock.fill",
                value: session.duration.shortFormatted,
                label: "Protected",
                color: .blue
            )
            
            SummaryStatCard(
                icon: "hand.raised.fill",
                value: "\(session.blockedAttempts.count)",
                label: "Blocked",
                color: session.blockedAttempts.isEmpty ? .green : .orange
            )
            
            SummaryStatCard(
                icon: "shield.checkmark.fill",
                value: session.blockedAttempts.isEmpty ? "100%" : "\(successRate)%",
                label: "Success",
                color: .green
            )
        }
    }
    
    private var successRate: Int {
        let blocked = session.blockedAttempts.filter { $0.outcome == .blocked }.count
        let total = session.blockedAttempts.count
        guard total > 0 else { return 100 }
        return Int((Double(blocked) / Double(total)) * 100)
    }
    
    private var blockedAttemptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("What You Avoided")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showDetails.toggle()
                    }
                } label: {
                    Text(showDetails ? "Hide" : "Show")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if showDetails {
                VStack(spacing: 8) {
                    ForEach(session.blockedAttempts) { attempt in
                        BlockedAttemptRow(attempt: attempt)
                    }
                }
            } else {
                // Summary view
                HStack(spacing: 20) {
                    if appAttempts > 0 {
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.blue)
                            Text("\(appAttempts) app\(appAttempts == 1 ? "" : "s")")
                        }
                    }
                    
                    if contactAttempts > 0 {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.red)
                            Text("\(contactAttempts) contact\(contactAttempts == 1 ? "" : "s")")
                        }
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    private var appAttempts: Int {
        session.blockedAttempts.filter { $0.attemptType == .app }.count
    }
    
    private var contactAttempts: Int {
        session.blockedAttempts.filter { $0.attemptType == .message || $0.attemptType == .call }.count
    }
    
    private var encouragementSection: some View {
        VStack(spacing: 12) {
            Text(encouragementMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(encouragementSubtext)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private var encouragementMessage: String {
        if session.blockedAttempts.isEmpty {
            return "🎉 Perfect Night!"
        } else if session.blockedAttempts.count <= 3 {
            return "💪 Great Self-Control!"
        } else {
            return "🛡️ Protection Worked!"
        }
    }
    
    private var encouragementSubtext: String {
        if session.blockedAttempts.isEmpty {
            return "You didn't try to reach any blocked contacts or apps. Well done!"
        } else {
            return "You blocked \(session.blockedAttempts.count) potential regret\(session.blockedAttempts.count == 1 ? "" : "s"). Future you says thanks!"
        }
    }
    
    private var shareSection: some View {
        Button {
            shareResults()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Your Success")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
    }
    
    private func shareResults() {
        let text = """
        🛡️ Booze Blocker Report
        
        Protected for: \(session.duration.shortFormatted)
        Blocked attempts: \(session.blockedAttempts.count)
        
        \(encouragementMessage)
        """
        
        // In production, use UIActivityViewController
        print(text)
    }
}

struct SummaryStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

struct BlockedAttemptRow: View {
    let attempt: BlockedAttempt
    
    var body: some View {
        HStack {
            Image(systemName: attempt.attemptType.icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.targetName)
                    .font(.subheadline)
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
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let session = ProtectionSession(
        startTime: Date().addingTimeInterval(-8 * 60 * 60),
        scheduledEndTime: Date(),
        activationType: .manual
    )
    
    return MorningSummaryView(session: session) {
        print("Dismissed")
    }
}
