import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
protocol BlockingController: AnyObject {
    var authorizationStatus: AuthorizationStatus { get }
    var isAuthorized: Bool { get }
    var selection: FamilyActivitySelection { get set }
    var hasSelection: Bool { get }
    var isBlocking: Bool { get }
    func requestAuthorization() async -> Bool
    func startBlocking(until endDate: Date?) throws
    func stopBlocking()
    func reconcile(sessionActive: Bool, endDate: Date?) throws
}

extension BlockingController {
    var isAuthorized: Bool { authorizationStatus == .approved }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    func reconcile(sessionActive: Bool, endDate: Date?) throws {
        if sessionActive && (endDate.map { $0 > Date() } ?? true) {
            try startBlocking(until: endDate)
        } else {
            stopBlocking()
        }
    }
}

@MainActor
final class ScreenTimeBlockingController: BlockingController {
    private let defaults: UserDefaults
    private let store = ManagedSettingsStore(named: .protection)
    private let activityCenter = DeviceActivityCenter()
    private(set) var isBlocking = false
    var authorizationStatus: AuthorizationStatus { AuthorizationCenter.shared.authorizationStatus }
    var selection: FamilyActivitySelection {
        didSet {
            if let data = try? JSONEncoder().encode(selection) {
                defaults.set(data, forKey: SharedKeys.activitySelection)
            }
        }
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: SharedKeys.activitySelection),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.selection = selection
        } else {
            selection = FamilyActivitySelection()
        }
    }

    func requestAuthorization() async -> Bool {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
        catch { return false }
        return isAuthorized
    }

    func startBlocking(until endDate: Date?) throws {
        stopBlocking()
        guard isAuthorized, hasSelection, endDate.map({ $0 > Date() }) ?? true else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.application.denyAppRemoval = true
        isBlocking = true
        let now = Date()
        guard let endDate, endDate.timeIntervalSince(now) >= 15 * 60 else { return }
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: now),
            intervalEnd: Calendar.current.dateComponents(components, from: endDate),
            repeats: false)
        try activityCenter.startMonitoring(.protectionSession, during: schedule)
    }

    func stopBlocking() {
        store.clearAllSettings()
        activityCenter.stopMonitoring([.protectionSession])
        isBlocking = false
    }
}

@MainActor
final class NoopBlockingController: BlockingController {
    var authorizationStatus: AuthorizationStatus { .notDetermined }
    var selection = FamilyActivitySelection()
    var isBlocking: Bool { false }
    func requestAuthorization() async -> Bool { false }
    func startBlocking(until endDate: Date?) throws {}
    func stopBlocking() {}
}
