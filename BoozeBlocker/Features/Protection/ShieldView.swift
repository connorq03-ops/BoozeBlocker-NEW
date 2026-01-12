import SwiftUI

/// View shown when user tries to access a blocked app
struct ShieldView: View {
    let appName: String
    let onStayProtected: () -> Void
    let onRequestAccess: () -> Void
    
    @EnvironmentObject var protectionManager: ProtectionManager
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Shield icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                    
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                
                // Message
                VStack(spacing: 12) {
                    Text("\(appName) is Blocked")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("This app is blocked while you're protected")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Time remaining
                if let timeRemaining = protectionManager.timeRemaining {
                    HStack {
                        Image(systemName: "clock")
                        Text(formatTimeRemaining(timeRemaining))
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .cornerRadius(20)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Primary: Stay Protected
                    Button {
                        onStayProtected()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Stay Protected")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.blue)
                        .cornerRadius(14)
                    }
                    
                    // Secondary: Request Access
                    Button {
                        onRequestAccess()
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.questionmark")
                            Text("Request 5 Minutes")
                        }
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes) minutes remaining"
        }
    }
}

/// Compact shield banner for overlay on apps
struct ShieldBanner: View {
    let message: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "shield.checkmark.fill")
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    ShieldView(
        appName: "Instagram",
        onStayProtected: {},
        onRequestAccess: {}
    )
    .environmentObject(ProtectionManager.shared)
}
