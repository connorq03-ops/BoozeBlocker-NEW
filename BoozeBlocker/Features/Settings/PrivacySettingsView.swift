import SwiftUI

struct PrivacySettingsView: View {
    @State private var storeHistoryLocally = true
    @State private var showBlockedAttemptDetails = true
    @State private var requireBiometricForHistory = false
    
    var body: some View {
        List {
            // Data Storage
            Section {
                Toggle("Store Session History", isOn: $storeHistoryLocally)
                
                if storeHistoryLocally {
                    Toggle("Show Blocked Attempt Details", isOn: $showBlockedAttemptDetails)
                }
            } header: {
                Text("Data Storage")
            } footer: {
                Text("All data is stored locally on your device. We never send your data to any server.")
            }
            
            // Security
            Section {
                Toggle("Require Face ID for History", isOn: $requireBiometricForHistory)
            } header: {
                Text("Security")
            } footer: {
                Text("Require biometric authentication to view your session history")
            }
            
            // Data Management
            Section {
                Button(role: .destructive) {
                    clearHistory()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Session History")
                    }
                }
                
                Button(role: .destructive) {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export My Data")
                    }
                    .foregroundColor(.blue)
                }
            } header: {
                Text("Data Management")
            }
            
            // Privacy Info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PrivacyInfoRow(
                        icon: "lock.shield.fill",
                        title: "Local Storage Only",
                        description: "All your data stays on your device"
                    )
                    
                    PrivacyInfoRow(
                        icon: "eye.slash.fill",
                        title: "No Tracking",
                        description: "We don't track your behavior or usage"
                    )
                    
                    PrivacyInfoRow(
                        icon: "server.rack",
                        title: "No Cloud Sync",
                        description: "Your data is never uploaded to any server"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Our Privacy Promise")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func clearHistory() {
        PersistenceService.shared.clearSessionHistory()
        HapticService.shared.success()
    }
    
    private func exportData() {
        // Export data as JSON
        let sessions = PersistenceService.shared.loadSessionHistory()
        let settings = PersistenceService.shared.loadUserSettings()
        
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "sessionCount": sessions.count,
            "settings": [
                "blockedApps": settings.blockedAppBundleIDs.count,
                "blockedContacts": settings.blockedContactIDs.count,
                "emergencyContacts": settings.emergencyContactIDs.count
            ]
        ]
        
        // In real implementation, would use UIActivityViewController to share
        print("Export data: \(exportData)")
    }
}

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
