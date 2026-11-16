import SwiftUI

@main
struct BoozeBlockerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var protectionManager: ProtectionManager
    @StateObject private var screenTimeService: ScreenTimeService
    @StateObject private var notificationService: NotificationService
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-resetState"),
           arguments.indices.contains(index + 1), arguments[index + 1] == "YES" {
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
            let appGroup = AppGroup.id
            UserDefaults(suiteName: appGroup)?.removePersistentDomain(forName: appGroup)
            hasCompletedOnboarding = false
            hasGrantedPermissions = false
        }
        #endif
        _protectionManager = StateObject(wrappedValue: ProtectionManager.shared)
        _screenTimeService = StateObject(wrappedValue: ScreenTimeService.shared)
        _notificationService = StateObject(wrappedValue: NotificationService.shared)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                hasGrantedPermissions: $hasGrantedPermissions
            )
            .preferredColorScheme(appearanceManager.colorScheme.colorScheme)
            .tint(appearanceManager.accentColor.color)
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
