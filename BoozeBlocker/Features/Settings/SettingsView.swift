import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var screenTime: ScreenTimeService
    @EnvironmentObject var protectionManager: ProtectionManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false
    @State private var settings = PersistenceService.shared.loadUserSettings()
    
    var body: some View {
        NavigationStack {
            List {
                // Blocked Apps Section
                Section {
                    NavigationLink {
                        BlockedAppsView()
                    } label: {
                        HStack {
                            Image(systemName: "app.badge.fill")
                                .foregroundColor(.blue)
                            Text("Blocked Apps")
                            Spacer()
                            Text("\(screenTime.selection.applicationTokens.count + screenTime.selection.categoryTokens.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("What to Block")
                }
                
                // Blocked Contacts Section
                Section {
                    NavigationLink {
                        BlockedContactsView()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .foregroundColor(.red)
                            Text("Blocked Contacts")
                            Spacer()
                            Text("\(settings.blockedContactIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        EmergencyContactsView()
                    } label: {
                        HStack {
                            Image(systemName: "staroflife.fill")
                                .foregroundColor(.green)
                            Text("Emergency Contacts")
                            Spacer()
                            Text("\(settings.emergencyContactIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Sobriety Test Section
                Section {
                    Picker("Test Difficulty", selection: $settings.sobrietyTestDifficulty) {
                        ForEach(SobrietyTestDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    
                    Text(settings.sobrietyTestDifficulty.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Sobriety Test")
                }
                
                // Notifications Section
                Section {
                    Toggle("Show Blocked Attempt Alerts", isOn: $settings.showBlockedAttemptNotifications)
                } header: {
                    Text("Notifications")
                }
                
                if FeatureFlags.schedulesEnabled {
                    Section {
                        NavigationLink {
                            ScheduleSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.orange)
                                Text("Scheduled Protection")
                            }
                        }
                    } header: {
                        Text("Automation")
                    } footer: {
                        Text("Automatically activate protection at set times")
                    }
                }

                Section {
                    if FeatureFlags.integrationsEnabled {
                        NavigationLink("Integrations (beta)") { IntegrationsView() }
                    }
                    if FeatureFlags.siriShortcutsEnabled {
                        NavigationLink("Siri Shortcuts") { SiriShortcutsView() }
                    }
                    if FeatureFlags.delayedMessagesEnabled {
                        NavigationLink("Message Preview (beta)") { MessagePreviewDemoView() }
                    }
                    if FeatureFlags.morningSummaryEnabled {
                        if let session = PersistenceService.shared.loadSessionHistory().first {
                            NavigationLink("Morning Summary") {
                                MorningSummaryDestination(session: session)
                            }
                        } else {
                            Text("Morning Summary available after a protection session")
                        }
                    }
                    if FeatureFlags.extraSobrietyTests.isEnabled() {
                        NavigationLink("Extra Sobriety Tests (practice)") { ExtraSobrietyTestsView() }
                    }
                }
                
                // Appearance Section
                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.purple)
                            Text("Appearance")
                        }
                    }
                } header: {
                    Text("Customization")
                }
                
                // Privacy & Help Section
                Section {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Privacy")
                        }
                    }
                    
                    NavigationLink {
                        HelpSupportView()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Help & Support")
                        }
                    }
                } header: {
                    Text("Support")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About Booze Blocker")
                    }
                } header: {
                    Text("About")
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        guard !protectionManager.isProtectionActive else { return }
                        screenTime.stopBlocking()
                        screenTime.selection = .init()
                        PersistenceService.shared.resetAllData()
                        settings = UserSettings()
                        protectionManager.reconcile()
                        hasCompletedOnboarding = false
                        hasGrantedPermissions = false
                    } label: {
                        Text("Reset All Data")
                    }
                    .disabled(protectionManager.isProtectionActive)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will clear all your settings, blocked contacts, and history.")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings) { _, newValue in
                PersistenceService.shared.saveUserSettings(newValue)
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Booze Blocker")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Protect yourself from drunk texting, calling, and app usage.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "app.badge.fill", title: "Block Apps", description: "Prevent access to social media, dating apps, and more")
                    FeatureRow(icon: "person.crop.circle.badge.xmark", title: "Block Contacts", description: "Stop yourself from texting or calling specific people")
                    FeatureRow(icon: "brain.head.profile", title: "Sobriety Tests", description: "Prove you're sober before deactivating protection")
                    FeatureRow(icon: "clock.fill", title: "Timed Protection", description: "Set protection to automatically end in the morning")
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
