internal import SwiftUI

@main
struct StorePalApp: App {
    @StateObject private var viewModel = StoreViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
        }
    }
}
