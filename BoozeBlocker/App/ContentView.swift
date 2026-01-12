import SwiftUI

struct ContentView: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    @StateObject private var deepLinkService = DeepLinkService.shared
    @State private var selectedTab: Tab = .home
    
    enum Tab: String {
        case home
        case settings
        case history
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EnhancedHomeView()
                .tabItem {
                    Label("Home", systemImage: "shield.fill")
                }
                .tag(Tab.home)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)
        }
        .tint(.blue)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: deepLinkService.pendingAction) { _, action in
            handlePendingAction(action)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        _ = deepLinkService.handle(url: url)
    }
    
    private func handlePendingAction(_ action: DeepLinkAction?) {
        guard let action = action else { return }
        
        switch action {
        case .activate(let duration):
            selectedTab = .home
            if let duration = duration {
                protectionManager.activateProtection(duration: duration)
            }
            
        case .deactivate:
            selectedTab = .home
            
        case .openSettings:
            selectedTab = .settings
            
        case .openHistory:
            selectedTab = .history
        }
        
        deepLinkService.clearPendingAction()
    }
}

#Preview {
    ContentView()
        .environmentObject(ProtectionManager.shared)
}
