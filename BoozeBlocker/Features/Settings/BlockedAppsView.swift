import SwiftUI

struct BlockedAppsView: View {
    @State private var apps: [BlockedApp] = []
    @State private var searchText: String = ""
    
    private let persistence = PersistenceService.shared
    
    var filteredApps: [BlockedApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var blockedCount: Int {
        apps.filter { $0.isBlocked }.count
    }
    
    var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    Image(systemName: "app.badge.fill")
                        .foregroundColor(.blue)
                    Text("\(blockedCount) apps will be blocked")
                        .foregroundColor(.secondary)
                }
            }
            
            // Apps List
            Section {
                ForEach($apps) { $app in
                    if searchText.isEmpty || app.displayName.localizedCaseInsensitiveContains(searchText) {
                        Toggle(isOn: $app.isBlocked) {
                            HStack {
                                AppIconPlaceholder(name: app.displayName)
                                Text(app.displayName)
                            }
                        }
                        .onChange(of: app.isBlocked) { _, _ in
                            saveApps()
                        }
                    }
                }
            } header: {
                Text("Select Apps to Block")
            } footer: {
                Text("These apps will be inaccessible while protection is active.")
            }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationTitle("Blocked Apps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadApps()
        }
    }
    
    private func loadApps() {
        let savedApps = persistence.loadBlockedApps()
        let savedBundleIDs = Set(savedApps.map { $0.bundleIdentifier })
        
        // Start with common apps, preserving saved blocked state
        var allApps = BlockedApp.commonApps.map { commonApp in
            if let savedApp = savedApps.first(where: { $0.bundleIdentifier == commonApp.bundleIdentifier }) {
                return savedApp
            }
            return commonApp
        }
        
        // Add any saved apps that aren't in common apps
        for savedApp in savedApps {
            if !BlockedApp.commonApps.contains(where: { $0.bundleIdentifier == savedApp.bundleIdentifier }) {
                allApps.append(savedApp)
            }
        }
        
        apps = allApps
    }
    
    private func saveApps() {
        let blockedApps = apps.filter { $0.isBlocked }
        persistence.saveBlockedApps(blockedApps)
        
        // Also update user settings
        var settings = persistence.loadUserSettings()
        settings.blockedAppBundleIDs = blockedApps.map { $0.bundleIdentifier }
        persistence.saveUserSettings(settings)
    }
}

struct AppIconPlaceholder: View {
    let name: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForApp(name))
                .frame(width: 32, height: 32)
            
            Text(String(name.prefix(1)))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func colorForApp(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .red, .indigo]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    NavigationStack {
        BlockedAppsView()
    }
}
