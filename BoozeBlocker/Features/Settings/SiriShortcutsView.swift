import SwiftUI
import Intents

/// Settings view for Siri Shortcuts integration
struct SiriShortcutsView: View {
    @State private var shortcuts: [ShortcutItem] = ShortcutItem.available
    
    var body: some View {
        List {
            // Info Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Siri Shortcuts")
                            .fontWeight(.semibold)
                        Text("Control Booze Blocker with your voice")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Available Shortcuts
            Section {
                ForEach(shortcuts) { shortcut in
                    ShortcutRow(shortcut: shortcut) {
                        addToSiri(shortcut)
                    }
                }
            } header: {
                Text("Available Shortcuts")
            } footer: {
                Text("Tap a shortcut to add it to Siri. You can customize the phrase in the Shortcuts app.")
            }
            
            // Example Phrases
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ExamplePhraseRow(phrase: "Hey Siri, activate Booze Blocker")
                    ExamplePhraseRow(phrase: "Hey Siri, I'm going out tonight")
                    ExamplePhraseRow(phrase: "Hey Siri, protect me for 6 hours")
                    ExamplePhraseRow(phrase: "Hey Siri, am I protected?")
                }
                .padding(.vertical, 8)
            } header: {
                Text("Example Phrases")
            }
        }
        .navigationTitle("Siri Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addToSiri(_ shortcut: ShortcutItem) {
        // In production, would use INUIAddVoiceShortcutViewController
        // to present the system UI for adding a shortcut
        
        let activity = NSUserActivity(activityType: shortcut.activityType)
        activity.title = shortcut.title
        activity.suggestedInvocationPhrase = shortcut.suggestedPhrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        // Donate the activity
        activity.becomeCurrent()
        
        HapticService.shared.success()
    }
}

struct ShortcutItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let suggestedPhrase: String
    let activityType: String
    let color: Color
    
    static let available: [ShortcutItem] = [
        ShortcutItem(
            title: "Activate Protection",
            subtitle: "Start protection with default duration",
            icon: "shield.checkmark.fill",
            suggestedPhrase: "Activate Booze Blocker",
            activityType: "com.boozeblocker.activate",
            color: .green
        ),
        ShortcutItem(
            title: "Quick 4-Hour Protection",
            subtitle: "Activate for exactly 4 hours",
            icon: "clock.fill",
            suggestedPhrase: "Protect me for 4 hours",
            activityType: "com.boozeblocker.activate.4hours",
            color: .blue
        ),
        ShortcutItem(
            title: "Until Morning",
            subtitle: "Activate until 8 AM",
            icon: "sunrise.fill",
            suggestedPhrase: "Protect me until morning",
            activityType: "com.boozeblocker.activate.morning",
            color: .orange
        ),
        ShortcutItem(
            title: "Check Status",
            subtitle: "Ask if protection is active",
            icon: "questionmark.circle.fill",
            suggestedPhrase: "Am I protected?",
            activityType: "com.boozeblocker.status",
            color: .purple
        ),
        ShortcutItem(
            title: "Stop Protection",
            subtitle: "Deactivate (requires sobriety test)",
            icon: "stop.fill",
            suggestedPhrase: "Stop Booze Blocker",
            activityType: "com.boozeblocker.deactivate",
            color: .red
        )
    ]
}

struct ShortcutRow: View {
    let shortcut: ShortcutItem
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(shortcut.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: shortcut.icon)
                    .foregroundColor(shortcut.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)
                    .fontWeight(.medium)
                
                Text(shortcut.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExamplePhraseRow: View {
    let phrase: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(phrase)
                .font(.subheadline)
                .italic()
            
            Image(systemName: "quote.closing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SiriShortcutsView()
    }
}
