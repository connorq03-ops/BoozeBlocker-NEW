import Foundation
import Combine
import FamilyControls

@MainActor
final class ScreenTimeService: ObservableObject, BlockingController {
    static let shared = ScreenTimeService()
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var isBlocking = false
    @Published private(set) var lastError: String?
    @Published var selection: FamilyActivitySelection {
        didSet { controller.selection = selection }
    }

    private let controller: BlockingController

    init(controller: BlockingController? = nil) {
        let resolved: BlockingController
        if let controller {
            resolved = controller
        } else {
            #if targetEnvironment(simulator)
            resolved = NoopBlockingController()
            #else
            resolved = ScreenTimeBlockingController()
            #endif
        }
        self.controller = resolved
        authorizationStatus = resolved.authorizationStatus
        selection = resolved.selection
        isBlocking = resolved.isBlocking
    }

    func checkAuthorizationStatus() {
        authorizationStatus = controller.authorizationStatus
        if !isAuthorized { controller.stopBlocking() }
        isBlocking = controller.isBlocking
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let authorized = await controller.requestAuthorization()
        checkAuthorizationStatus()
        return authorized
    }

    func startBlocking(until endDate: Date?) throws {
        lastError = nil
        defer { refreshState() }
        do { try controller.startBlocking(until: endDate) }
        catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func stopBlocking() {
        controller.stopBlocking()
        refreshState()
    }

    func reconcile(sessionActive: Bool, endDate: Date?) throws {
        lastError = nil
        defer { refreshState() }
        do { try controller.reconcile(sessionActive: sessionActive, endDate: endDate) }
        catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func refreshState() {
        authorizationStatus = controller.authorizationStatus
        isBlocking = controller.isBlocking
    }
}
