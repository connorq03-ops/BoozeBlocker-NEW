import Foundation
import Combine

/// Service for Oura Ring integration (v2.0 feature)
/// Detects drinking through biometric changes
class OuraService: ObservableObject {
    static let shared = OuraService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var latestReadings: OuraReadings?
    @Published private(set) var drinkingDetected: Bool = false
    @Published private(set) var drinkingConfidence: Double = 0.0
    
    // MARK: - Private Properties
    
    private var accessToken: String?
    private var refreshToken: String?
    private var cancellables = Set<AnyCancellable>()
    
    // Oura API endpoints
    private let baseURL = "https://api.ouraring.com/v2"
    private let authURL = "https://cloud.ouraring.com/oauth/authorize"
    
    // Detection thresholds
    private let hrvDropThreshold: Double = 0.15 // 15% drop from baseline
    private let hrElevationThreshold: Double = 10 // 10 bpm above resting
    private let tempElevationThreshold: Double = 0.3 // 0.3°C above baseline
    
    private init() {
        loadCredentials()
    }
    
    // MARK: - OAuth Flow
    
    /// Generate OAuth authorization URL
    func getAuthorizationURL(clientId: String, redirectURI: String) -> URL? {
        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "daily heartrate personal")
        ]
        return components?.url
    }
    
    /// Handle OAuth callback
    func handleCallback(code: String, clientId: String, clientSecret: String, redirectURI: String) async -> Bool {
        // In production, exchange code for tokens
        // This is a placeholder for the OAuth token exchange
        
        let tokenURL = "https://api.ouraring.com/oauth/token"
        
        guard let url = URL(string: tokenURL) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            if let tokenResponse = try? JSONDecoder().decode(OuraTokenResponse.self, from: data) {
                accessToken = tokenResponse.accessToken
                refreshToken = tokenResponse.refreshToken
                saveCredentials()
                
                await MainActor.run {
                    isAuthorized = true
                    isConnected = true
                }
                
                return true
            }
        } catch {
            print("Oura OAuth error: \(error)")
        }
        
        return false
    }
    
    /// Disconnect from Oura
    func disconnect() {
        accessToken = nil
        refreshToken = nil
        clearCredentials()
        
        isConnected = false
        isAuthorized = false
        latestReadings = nil
        drinkingDetected = false
    }
    
    // MARK: - Data Fetching
    
    /// Fetch latest biometric data
    func fetchLatestData() async {
        guard let token = accessToken else { return }
        
        // Fetch heart rate data
        let heartRateData = await fetchHeartRate(token: token)
        
        // Fetch HRV data
        let hrvData = await fetchHRV(token: token)
        
        // Fetch body temperature
        let tempData = await fetchBodyTemperature(token: token)
        
        let readings = OuraReadings(
            timestamp: Date(),
            heartRate: heartRateData?.average ?? 0,
            restingHeartRate: heartRateData?.resting ?? 0,
            hrv: hrvData?.average ?? 0,
            hrvBaseline: hrvData?.baseline ?? 0,
            bodyTemperature: tempData?.deviation ?? 0
        )
        
        await MainActor.run {
            latestReadings = readings
            analyzeForDrinking(readings)
        }
    }
    
    // MARK: - Drinking Detection
    
    /// Analyze readings to detect potential drinking
    private func analyzeForDrinking(_ readings: OuraReadings) {
        var confidence: Double = 0.0
        
        // Check HRV drop
        if readings.hrvBaseline > 0 {
            let hrvDrop = (readings.hrvBaseline - readings.hrv) / readings.hrvBaseline
            if hrvDrop > hrvDropThreshold {
                confidence += 0.4
            }
        }
        
        // Check elevated heart rate
        if readings.restingHeartRate > 0 {
            let hrElevation = readings.heartRate - readings.restingHeartRate
            if hrElevation > hrElevationThreshold {
                confidence += 0.3
            }
        }
        
        // Check body temperature elevation
        if readings.bodyTemperature > tempElevationThreshold {
            confidence += 0.3
        }
        
        // Check time of day (evening/night increases likelihood)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 || hour <= 2 {
            confidence *= 1.2 // 20% boost for evening hours
        }
        
        drinkingConfidence = min(confidence, 1.0)
        drinkingDetected = drinkingConfidence > 0.6
        
        if drinkingDetected {
            NotificationCenter.default.post(
                name: .ouraDetectedDrinking,
                object: drinkingConfidence
            )
        }
    }
    
    // MARK: - API Calls (Placeholders)
    
    private func fetchHeartRate(token: String) async -> HeartRateData? {
        // Placeholder - would call Oura API
        return nil
    }
    
    private func fetchHRV(token: String) async -> HRVData? {
        // Placeholder - would call Oura API
        return nil
    }
    
    private func fetchBodyTemperature(token: String) async -> TemperatureData? {
        // Placeholder - would call Oura API
        return nil
    }
    
    // MARK: - Credential Storage
    
    private func saveCredentials() {
        // In production, use Keychain
        UserDefaults.standard.set(accessToken, forKey: "ouraAccessToken")
        UserDefaults.standard.set(refreshToken, forKey: "ouraRefreshToken")
    }
    
    private func loadCredentials() {
        accessToken = UserDefaults.standard.string(forKey: "ouraAccessToken")
        refreshToken = UserDefaults.standard.string(forKey: "ouraRefreshToken")
        isConnected = accessToken != nil
        isAuthorized = accessToken != nil
    }
    
    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: "ouraAccessToken")
        UserDefaults.standard.removeObject(forKey: "ouraRefreshToken")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ouraDetectedDrinking = Notification.Name("ouraDetectedDrinking")
}

// MARK: - Data Models

struct OuraTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct OuraReadings {
    let timestamp: Date
    let heartRate: Double
    let restingHeartRate: Double
    let hrv: Double
    let hrvBaseline: Double
    let bodyTemperature: Double
}

struct HeartRateData {
    let average: Double
    let resting: Double
}

struct HRVData {
    let average: Double
    let baseline: Double
}

struct TemperatureData {
    let deviation: Double
}
