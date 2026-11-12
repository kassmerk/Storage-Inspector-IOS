import Foundation
import SwiftUI

/// Single source of truth for the Storage screen.
final class StorageStore: ObservableObject {
    @Published private(set) var apps: [AppItem] = []
    @Published private(set) var capacity: DeviceCapacity = .empty
    @Published private(set) var selfApp: AppItem
    @Published private(set) var lastRefresh: Date = Date()

    init() {
        selfApp = StorageStore.makeSelfApp()
        apps = DemoCatalog.apps
        capacity = DeviceStorage.capacity()
    }

    /// Re-reads device capacity and this app's own sizes.
    func refresh() {
        capacity = DeviceStorage.capacity()
        selfApp = StorageStore.makeSelfApp()
        lastRefresh = Date()
    }

    func remove(_ app: AppItem) {
        apps.removeAll { $0.id == app.id }
    }

    func restoreDemoApps() {
        apps = DemoCatalog.apps
    }

    var demoTotal: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    var applicationsTotal: Int64 {
        demoTotal + selfApp.totalSize
    }

    private static func makeSelfApp() -> AppItem {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "This App"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "1.0"

        return AppItem(
            id: "self",
            name: name,
            developer: "This device",
            version: version,
            symbol: "externaldrive.fill",
            tint: [Theme.accent, Theme.indigo],
            appSize: SandboxFiles.appBundleSize(),
            dataSize: SandboxFiles.dataContainerSize(),
            lastUsed: "Today",
            isReal: true
        )
    }
}
