import SwiftUI
import FamilyControls

struct BlockedAppsView: View {
    @EnvironmentObject var screenTime: ScreenTimeService
    @EnvironmentObject var protectionManager: ProtectionManager
    @State private var showPicker = false

    var body: some View {
        List {
            #if targetEnvironment(simulator)
            Section { Text("Screen Time requires a real device") }
            #else
            if !screenTime.isAuthorized {
                Section {
                    Button("Allow Screen Time Access") {
                        Task { await screenTime.requestAuthorization() }
                    }
                }
            }
            #endif
            Section {
                Button("Choose Apps & Categories") { showPicker = true }
                    .disabled(!screenTime.isAuthorized || protectionManager.isProtectionActive)
            } footer: {
                if protectionManager.isProtectionActive {
                    Text("You can't change blocked apps while protection is active.")
                } else {
                    Text("Your selection never leaves your device.")
                }
            }
            Section("Apps") {
                ForEach(Array(screenTime.selection.applicationTokens), id: \.self) { Label($0) }
            }
            Section("Categories") {
                ForEach(Array(screenTime.selection.categoryTokens), id: \.self) { Label($0) }
            }
            Section("Websites") {
                ForEach(Array(screenTime.selection.webDomainTokens), id: \.self) { Label($0) }
            }
            if let error = screenTime.lastError {
                Section { Text(error).foregroundStyle(.orange) }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(
            get: { screenTime.selection },
            set: { if !protectionManager.isProtectionActive { screenTime.selection = $0 } }))
        .onChange(of: protectionManager.isProtectionActive) { _, active in
            if active { showPicker = false }
        }
        .navigationTitle("Blocked Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}
