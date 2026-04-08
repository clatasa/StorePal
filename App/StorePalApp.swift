internal import SwiftUI

// MARK: - App delegate (silent push → sync shared lists)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var onSilentPush: (() async -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Required for CloudKit silent push delivery.
        // Silent pushes don't require user permission but do need device token registration.
        application.registerForRemoteNotifications()
        // Receive notification taps even when the app is in the foreground.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when the user taps a delivered notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let listIdString = response.notification.request.content.userInfo["listId"] as? String,
           let url = URL(string: "storepal://list/\(listIdString)") {
            UIApplication.shared.open(url)
        }
        completionHandler()
    }

    // Show the notification as a banner even when the app is already open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            await onSilentPush?()
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Failed to register: \(error)")
    }
}

// MARK: - App entry point

@main
struct StorePalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel     = StoreViewModel()
    @StateObject private var listViewModel = ListViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .environmentObject(listViewModel)
                .task {
                    // Wire silent push → sync
                    appDelegate.onSilentPush = { [weak listViewModel] in
                        await listViewModel?.syncSharedLists()
                    }
                    // Sync shared lists on every launch
                    await listViewModel.syncSharedLists()
                }
        }
    }
}
