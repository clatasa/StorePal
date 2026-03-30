import UserNotifications
import Combine


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

    func sendAlert(for store: GroceryStore) {
        let content = UNMutableNotificationContent()
        content.title = "Grocery Store Nearby"
        content.body  = "You're near \(store.name). Don't forget to stop by!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "geofence-\(store.id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil   // fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
