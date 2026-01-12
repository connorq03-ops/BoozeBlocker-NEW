import Foundation
import LocalAuthentication

/// Service for biometric authentication (Face ID / Touch ID)
class BiometricService: ObservableObject {
    static let shared = BiometricService()
    
    // MARK: - Published Properties
    
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var isAvailable: Bool = false
    
    // MARK: - Private Properties
    
    private let context = LAContext()
    
    // MARK: - Initialization
    
    private init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Check what biometric authentication is available
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isAvailable = true
            
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                biometricType = .opticID
            @unknown default:
                biometricType = .none
            }
        } else {
            isAvailable = false
            biometricType = .none
        }
    }
    
    /// Authenticate user with biometrics
    /// - Parameter reason: The reason shown to the user
    /// - Returns: True if authentication succeeded
    func authenticate(reason: String) async -> Bool {
        guard isAvailable else { return false }
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            print("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Authenticate with fallback to passcode
    func authenticateWithFallback(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "lock"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}
