internal import SwiftUI

@main
struct StorePalApp: App {
    @StateObject private var viewModel     = StoreViewModel()
    @StateObject private var listViewModel = ListViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .environmentObject(listViewModel)
        }
    }
}
