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
        // Woken in background: read everything directly from UserDefaults —
        // the SwiftUI view hierarchy may not be initialized.
        guard
            let storeData = UserDefaults.standard.data(forKey: "favorites"),
            let stores    = try? JSONDecoder().decode([GroceryStore].self, from: storeData),
            let listData  = UserDefaults.standard.data(forKey: "groceryLists"),
            let lists     = try? JSONDecoder().decode([GroceryList].self, from: listData)
        else { return }

        let behaviorRaw = UserDefaults.standard.string(forKey: GeofenceAlertBehavior.defaultsKey) ?? "always"
        let behavior    = GeofenceAlertBehavior(rawValue: behaviorRaw) ?? .always

        guard let payload = Self.alertPayload(
            storeId: region.identifier, stores: stores, lists: lists, behavior: behavior
        ) else { return }

        NotificationService.shared.sendAlert(
            for: payload.store, listName: payload.listName, itemCount: payload.itemCount
        )
    }

    /// Pure decision function: returns what to notify (or nil if silent).
    /// Extracted so it can be unit-tested without side effects.
    static func alertPayload(
        storeId: String,
        stores: [GroceryStore],
        lists: [GroceryList],
        behavior: GeofenceAlertBehavior
    ) -> (store: GroceryStore, listName: String?, itemCount: Int?)? {
        guard let store = stores.first(where: { $0.id == storeId }) else { return nil }
        switch behavior {
        case .always:
            return (store, nil, nil)
        case .linkedList:
            guard let match = lists.first(where: { $0.boundStoreId == store.id })
            else { return nil }
            return (store, match.name, nil)
        case .itemsNeeded:
            guard let match = lists.first(where: { $0.boundStoreId == store.id && $0.activeCount > 0 })
            else { return nil }
            return (store, match.name, match.activeCount)
        }
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
