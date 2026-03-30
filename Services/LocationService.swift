import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var monitoredRegions: Set<CLRegion> { manager.monitoredRegions }
    var maximumMonitoringRadius: CLLocationDistance { manager.maximumRegionMonitoringDistance }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Auth

    /// Call this first. iOS requires WhenInUse before Always.
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Call this after WhenInUse is granted, to enable background geo-fencing.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    /// Requests a single one-shot location fix. Fires didUpdateLocations once then stops.
    func requestOneTimeLocation() {
        manager.requestLocation()
    }

    // MARK: - Region monitoring

    func startMonitoring(store: GroceryStore, radius: Double) {
        let clamped = min(max(radius, 100), maximumMonitoringRadius)
        let region = CLCircularRegion(
            center: store.coordinate,
            radius: clamped,
            identifier: store.id
        )
        region.notifyOnEntry = true
        region.notifyOnExit  = false
        manager.startMonitoring(for: region)
    }

    func stopMonitoring(storeId: String) {
        if let region = manager.monitoredRegions.first(where: { $0.identifier == storeId }) {
            manager.stopMonitoring(for: region)
        }
    }

    func stopMonitoringAll() {
        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { self.currentLocation = locations.last }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways ||
               manager.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Woken in background: resolve store name directly from UserDefaults,
        // without depending on the SwiftUI view hierarchy being initialized.
        guard
            let data   = UserDefaults.standard.data(forKey: "favorites"),
            let stores = try? JSONDecoder().decode([GroceryStore].self, from: data),
            let store  = stores.first(where: { $0.id == region.identifier })
        else { return }
        NotificationService.shared.sendAlert(for: store)
    }

    func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        print("Geo-fence failed for \(region?.identifier ?? "?"): \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
