import SwiftUI

struct HomeView: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    @State private var showDurationPicker = false
    @State private var showDeactivateConfirm = false
    @State private var showSobrietyTest = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Status indicator
                    statusCard
                    
                    // Main action button
                    mainActionButton
                    
                    // Quick stats (when active)
                    if protectionManager.isProtectionActive {
                        activeSessionInfo
                    }
                    
                    Spacer()
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Booze Blocker")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet { duration in
                protectionManager.activateProtection(duration: duration)
                showDurationPicker = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSobrietyTest) {
            SobrietyTestView { passed in
                if passed {
                    protectionManager.deactivateProtection(reason: .sobrietyTestPassed)
                }
                showSobrietyTest = false
            }
        }
        .confirmationDialog(
            "Deactivate Protection?",
            isPresented: $showDeactivateConfirm,
            titleVisibility: .visible
        ) {
            Button("Take Sobriety Test", role: .destructive) {
                showSobrietyTest = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to pass a sobriety test to deactivate protection.")
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: protectionManager.isProtectionActive
                ? [Color.green.opacity(0.3), Color.blue.opacity(0.2)]
                : [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(protectionManager.isProtectionActive ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Image(systemName: protectionManager.isProtectionActive ? "shield.checkmark.fill" : "shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            // Status text
            Text(protectionManager.isProtectionActive ? "PROTECTED" : "NOT PROTECTED")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(protectionManager.isProtectionActive ? .green : .secondary)
            
            // Time remaining
            if protectionManager.isProtectionActive {
                Text(protectionManager.formattedTimeRemaining())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var mainActionButton: some View {
        Button {
            if protectionManager.isProtectionActive {
                showDeactivateConfirm = true
            } else {
                showDurationPicker = true
            }
        } label: {
            HStack {
                Image(systemName: protectionManager.isProtectionActive ? "stop.fill" : "play.fill")
                Text(protectionManager.isProtectionActive ? "Stop Protection" : "Activate Protection")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(protectionManager.isProtectionActive ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var activeSessionInfo: some View {
        VStack(spacing: 12) {
            if let session = protectionManager.currentSession {
                HStack {
                    Label("Started", systemImage: "clock")
                    Spacer()
                    Text(session.startTime, style: .time)
                }
                
                HStack {
                    Label("Blocked Attempts", systemImage: "hand.raised.fill")
                    Spacer()
                    Text("\(session.blockedAttempts.count)")
                        .fontWeight(.semibold)
                        .foregroundColor(session.blockedAttempts.isEmpty ? .green : .orange)
                }
            }
        }
        .font(.subheadline)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
        .environmentObject(ProtectionManager.shared)
}
