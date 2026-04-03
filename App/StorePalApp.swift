internal import SwiftUI

// MARK: - App delegate (silent push → sync shared lists)

class AppDelegate: NSObject, UIApplicationDelegate {
    var onSilentPush: (() async -> Void)?

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
