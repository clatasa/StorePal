import UserNotifications
import Combine

// MARK: - Alert behavior

enum GeofenceAlertBehavior: String, CaseIterable {
    case always      = "always"
    case linkedList  = "linkedList"
    case itemsNeeded = "itemsNeeded"

    var label: String {
        switch self {
        case .always:      return "Always"
        case .linkedList:  return "Linked List"
        case .itemsNeeded: return "Items Needed"
        }
    }

    var detail: String {
        switch self {
        case .always:      return "whenever you're near a saved store"
        case .linkedList:  return "only when a list is linked to that store"
        case .itemsNeeded: return "only when a linked list has unchecked items"
        }
    }

    static let defaultsKey = "geofenceAlertBehavior"
}

// MARK: - Service

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private init() {}

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
        } catch {
            print("Notification auth error: \(error)")
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    func sendAlert(for store: GroceryStore, listName: String? = nil, itemCount: Int? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Grocery Store Nearby"
        if let listName, let itemCount {
            content.body = "You're near \(store.name) — \(itemCount) item\(itemCount == 1 ? "" : "s") to pick up for \"\(listName)\"."
        } else if let listName {
            content.body = "You're near \(store.name). Your \"\(listName)\" list is linked here."
        } else {
            content.body = "You're near \(store.name). Don't forget to stop by!"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "geofence-\(store.id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
