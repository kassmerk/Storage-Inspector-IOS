import SwiftUI

@main
struct StorageInspectorApp: App {
    @StateObject private var store = StorageStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
