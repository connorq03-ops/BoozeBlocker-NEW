import SwiftUI

struct StatusCard: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated shield
            AnimatedShield(isActive: protectionManager.isProtectionActive)
            
            // Status text
            VStack(spacing: 8) {
                Text(protectionManager.isProtectionActive ? "PROTECTED" : "NOT PROTECTED")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(protectionManager.isProtectionActive ? .green : .secondary)
                
                if protectionManager.isProtectionActive {
                    Text(protectionManager.formattedTimeRemaining())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to activate protection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Session stats (when active)
            if protectionManager.isProtectionActive, let session = protectionManager.currentSession {
                SessionStatsRow(session: session)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: protectionManager.isProtectionActive ? .green.opacity(0.2) : .clear, radius: 20)
        )
    }
}

struct AnimatedShield: View {
    let isActive: Bool
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer glow (when active)
            if isActive {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
            
            // Main circle
            Circle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 120, height: 120)
            
            // Shield icon
            Image(systemName: isActive ? "shield.checkmark.fill" : "shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: isActive)
        }
        .onAppear {
            isPulsing = isActive
        }
        .onChange(of: isActive) { _, newValue in
            isPulsing = newValue
        }
    }
}

struct SessionStatsRow: View {
    let session: ProtectionSession
    
    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                icon: "clock",
                value: session.startTime.timeString,
                label: "Started"
            )
            
            Divider()
                .frame(height: 30)
            
            StatItem(
                icon: "hand.raised.fill",
                value: "\(session.blockedAttempts.count)",
                label: "Blocked",
                valueColor: session.blockedAttempts.isEmpty ? .green : .orange
            )
        }
        .padding(.top, 8)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(valueColor)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StatusCard()
        .environmentObject(ProtectionManager.shared)
        .padding()
}
