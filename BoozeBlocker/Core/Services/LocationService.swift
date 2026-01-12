import Foundation
import CoreLocation
import Combine

/// Service for location-based protection triggers
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    // MARK: - Published Properties
    
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isMonitoringRegions: Bool = false
    @Published private(set) var triggeredLocation: SavedLocation?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private var savedLocations: [SavedLocation] = []
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        checkAuthorizationStatus()
        loadSavedLocations()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Location Monitoring
    
    /// Start monitoring saved locations for entry
    func startMonitoring() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        
        // Clear existing regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        // Monitor saved locations
        for location in savedLocations where location.isEnabled {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                radius: location.radius,
                identifier: location.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            locationManager.startMonitoring(for: region)
        }
        
        isMonitoringRegions = true
    }
    
    /// Stop monitoring all regions
    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        isMonitoringRegions = false
    }
    
    // MARK: - Saved Locations
    
    func addLocation(_ location: SavedLocation) {
        savedLocations.append(location)
        saveToPersistence()
        
        if isMonitoringRegions {
            startMonitoring()
        }
    }
    
    func removeLocation(id: UUID) {
        savedLocations.removeAll { $0.id == id }
        saveToPersistence()
        
        if isMonitoringRegions {
            startMonitoring()
        }
    }
    
    func updateLocation(_ location: SavedLocation) {
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            savedLocations[index] = location
            saveToPersistence()
            
            if isMonitoringRegions {
                startMonitoring()
            }
        }
    }
    
    func getSavedLocations() -> [SavedLocation] {
        return savedLocations
    }
    
    // MARK: - Persistence
    
    private func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: "savedLocations"),
           let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = locations
        }
    }
    
    private func saveToPersistence() {
        if let data = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(data, forKey: "savedLocations")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let locationId = UUID(uuidString: circularRegion.identifier),
              let savedLocation = savedLocations.first(where: { $0.id == locationId }) else {
            return
        }
        
        triggeredLocation = savedLocation
        
        // Post notification for protection activation
        NotificationCenter.default.post(
            name: .locationTriggered,
            object: savedLocation
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let locationTriggered = Notification.Name("locationTriggered")
}

// MARK: - Saved Location Model

struct SavedLocation: Codable, Identifiable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double // in meters
    var locationType: LocationType
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        locationType: LocationType = .bar,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.locationType = locationType
        self.isEnabled = isEnabled
    }
}

enum LocationType: String, Codable, CaseIterable {
    case bar
    case club
    case restaurant
    case home
    case friendsPlace
    case other
    
    var displayName: String {
        switch self {
        case .bar: return "Bar"
        case .club: return "Club"
        case .restaurant: return "Restaurant"
        case .home: return "Home"
        case .friendsPlace: return "Friend's Place"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .bar: return "wineglass.fill"
        case .club: return "music.note.house.fill"
        case .restaurant: return "fork.knife"
        case .home: return "house.fill"
        case .friendsPlace: return "person.2.fill"
        case .other: return "mappin"
        }
    }
}
