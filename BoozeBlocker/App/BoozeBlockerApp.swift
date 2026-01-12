import SwiftUI

@main
struct BoozeBlockerApp: App {
    @StateObject private var protectionManager = ProtectionManager.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false
    
    var body: some Scene {
        WindowGroup {
            RootView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                hasGrantedPermissions: $hasGrantedPermissions
            )
            .environmentObject(protectionManager)
            .environmentObject(screenTimeService)
            .environmentObject(notificationService)
            .onAppear {
                setupAppearance()
            }
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

struct RootView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var hasGrantedPermissions: Bool
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            } else if !hasGrantedPermissions {
                PermissionsView(hasGrantedPermissions: $hasGrantedPermissions)
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: hasGrantedPermissions)
    }
}
