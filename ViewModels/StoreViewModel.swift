import Foundation
import MapKit
import Combine
internal import SwiftUI


@MainActor
class StoreViewModel: ObservableObject {

    // MARK: - State

    @Published var favorites: [GroceryStore] = [] {
        didSet { persistFavorites(); syncGeofences() }
    }

    @Published var searchResults: [GroceryStore] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    @Published var geofenceRadius: Double = 500 {
        didSet {
            UserDefaults.standard.set(geofenceRadius, forKey: "geofenceRadius")
            resyncGeofences()
        }
    }

    // MARK: - Services

    let locationService    = LocationService.shared
    let notificationService = NotificationService.shared

    // MARK: - Computed

    var favoriteIds: Set<String> { Set(favorites.map { $0.id }) }
    let maxFavorites = 5
    var canAddFavorite: Bool { favorites.count < maxFavorites }

    // MARK: - Init

    init() {
        loadFavorites()
        let saved = UserDefaults.standard.double(forKey: "geofenceRadius")
        if saved > 0 { geofenceRadius = saved }
    }

    // MARK: - Favorites

    func toggleFavorite(_ store: GroceryStore) {
        if favoriteIds.contains(store.id) {
            favorites.removeAll { $0.id == store.id }
        } else if canAddFavorite {
            favorites.append(store)
        }
    }

    func removeFavorite(at offsets: IndexSet) {
        offsets.forEach { locationService.stopMonitoring(storeId: favorites[$0].id) }
        favorites.remove(atOffsets: offsets)
    }

    // MARK: - Search (MapKit MKLocalSearch)

    func searchNearby() async {
        // If no location yet, ensure permission is granted then request a one-shot fix.
        if locationService.currentLocation == nil {
            let status = locationService.authorizationStatus
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                errorMessage = "Location access is required. Tap the gear icon to fix permissions."
                return
            }
            locationService.requestOneTimeLocation()
            // Poll up to 5 seconds for the first fix to arrive.
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if locationService.currentLocation != nil { break }
            }
        }

        guard let location = locationService.currentLocation else {
            errorMessage = "Could not get your location. Make sure Location is set to 'While Using the App'."
            return
        }
        isSearching = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "grocery store"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let coord = item.placemark.coordinate
                return GroceryStore(
                    // Stable ID: name + truncated coordinates
                    id: "\(name)_\(String(format: "%.4f", coord.latitude))_\(String(format: "%.4f", coord.longitude))",
                    name: name,
                    address: item.placemark.title ?? item.placemark.thoroughfare ?? "",
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }

        isSearching = false
    }

    // MARK: - Permissions

    func requestPermissions() async {
        // Always request WhenInUse first — iOS requires this before Always.
        // The Settings sheet will prompt the user to upgrade to Always for geo-fencing.
        locationService.requestWhenInUseAuthorization()
        await notificationService.requestAuthorization()
        await notificationService.checkStatus()
    }

    // MARK: - Geo-fence sync

    private func syncGeofences() {
        let monitoredIds = Set(locationService.monitoredRegions.map { $0.identifier })
        // Start monitoring for newly added favorites
        for store in favorites where !monitoredIds.contains(store.id) {
            locationService.startMonitoring(store: store, radius: geofenceRadius)
        }
        // Stop monitoring removed favorites
        for region in locationService.monitoredRegions where !favoriteIds.contains(region.identifier) {
            locationService.stopMonitoring(storeId: region.identifier)
        }
    }

    private func resyncGeofences() {
        // Called when radius changes: rebuild all regions with new radius
        locationService.stopMonitoringAll()
        favorites.forEach { locationService.startMonitoring(store: $0, radius: geofenceRadius) }
    }

    // MARK: - Persistence

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "favorites")
        }
    }

    private func loadFavorites() {
        if let data  = UserDefaults.standard.data(forKey: "favorites"),
           let stores = try? JSONDecoder().decode([GroceryStore].self, from: data) {
            // Assign without triggering didSet → manually sync after
            _favorites = Published(wrappedValue: stores)
        }
        // Ensure geo-fences match persisted state (e.g. after reinstall)
        syncGeofences()
    }
}
