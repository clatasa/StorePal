import Foundation
import CoreLocation

struct GroceryStore: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var geofenceRadiusOverride: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GroceryStore, rhs: GroceryStore) -> Bool { lhs.id == rhs.id }
}
