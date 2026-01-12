import SwiftUI

/// Enhanced home view with all components
struct EnhancedHomeView: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    @State private var showDurationPicker = false
    @State private var showDeactivateConfirm = false
    @State private var showSobrietyTest = false
    @State private var sessions: [ProtectionSession] = []
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status card
                    StatusCard()
                        .padding(.horizontal)
                    
                    // Main action button
                    mainActionButton
                        .padding(.horizontal)
                    
                    // Quick actions (when not protected)
                    if !protectionManager.isProtectionActive {
                        QuickActionsView { duration in
                            if let duration = duration {
                                protectionManager.activateProtection(duration: duration)
                            } else {
                                showDurationPicker = true
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Recent activity
                    RecentActivityCard(sessions: sessions)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Booze Blocker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .onAppear {
                loadSessions()
            }
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
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: protectionManager.isProtectionActive
                ? [Color.green.opacity(0.15), Color.blue.opacity(0.1)]
                : [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var mainActionButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            if protectionManager.isProtectionActive {
                showDeactivateConfirm = true
            } else {
                showDurationPicker = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: protectionManager.isProtectionActive ? "stop.fill" : "shield.checkmark.fill")
                    .font(.title3)
                
                Text(protectionManager.isProtectionActive ? "Stop Protection" : "Activate Protection")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(protectionManager.isProtectionActive ? Color.red : Color.blue)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
    
    private func loadSessions() {
        sessions = persistence.loadSessionHistory()
    }
}

#Preview {
    EnhancedHomeView()
        .environmentObject(ProtectionManager.shared)
}
