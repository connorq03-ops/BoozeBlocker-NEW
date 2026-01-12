import SwiftUI

struct AppearanceSettingsView: View {
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        List {
            // Color Scheme
            Section {
                ForEach(ColorSchemePreference.allCases, id: \.self) { preference in
                    HStack {
                        Text(preference.displayName)
                        Spacer()
                        if appearanceManager.colorScheme == preference {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appearanceManager.colorScheme = preference
                    }
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how Booze Blocker looks")
            }
            
            // Accent Color
            Section {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(AccentColorOption.allCases, id: \.self) { option in
                        ColorOptionButton(
                            option: option,
                            isSelected: appearanceManager.accentColor == option
                        ) {
                            appearanceManager.accentColor = option
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Accent Color")
            }
            
            // Haptic Feedback
            Section {
                Toggle("Haptic Feedback", isOn: $appearanceManager.hapticFeedbackEnabled)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Feel a vibration when you tap buttons")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorOptionButton: View {
    let option: AccentColorOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 50, height: 50)
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                Text(option.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? option.color : .secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
