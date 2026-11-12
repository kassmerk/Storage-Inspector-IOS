import Foundation
import SwiftUI

/// Single source of truth for the Storage screen.
final class StorageStore: ObservableObject {
    /// State of the private-API scan of the installed apps.
    enum InstalledState: Equatable {
        case idle
        case loading
        case ready
        case empty
        case unavailable(String)
    }

    @Published private(set) var apps: [AppItem] = []
    /// Apps really installed on this iPhone (`LSApplicationWorkspace`), empty until scanned.
    @Published private(set) var installedApps: [AppItem] = []
    @Published private(set) var installedState: InstalledState = .idle
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

    /// Reads the list of really installed apps through the private API. The scan is cached for
    /// the session: pass `force: true` to repeat it (the Settings switch does that).
    func loadInstalledApps(force: Bool = false) {
        if case .loading = installedState { return }
        if !force {
            if case .ready = installedState { return }
            if case .empty = installedState { return }
        }

        if let reason = InstalledAppsProvider.unavailableReason {
            installedState = .unavailable(reason)
            return
        }

        installedState = .loading
        let ownBundleID = Bundle.main.bundleIdentifier

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = InstalledAppsProvider.loadApps()
            let items = found
                .filter { $0.bundleID != ownBundleID }
                .map { StorageStore.makeInstalledApp($0) }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.installedApps = items
                self.installedState = items.isEmpty ? .empty : .ready
            }
        }
    }

    var demoTotal: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    /// One row per installed app. iOS reveals the name, the version and the icon, but never the
    /// size, so `hasKnownSize` is `false` and the UI prints a dash instead of a fake number.
    private static func makeInstalledApp(_ app: InstalledAppsProvider.InstalledApp) -> AppItem {
        AppItem(
            id: app.bundleID,
            bundleID: app.bundleID,
            name: app.name,
            developer: app.developer,
            version: app.version,
            symbol: "app.dashed",
            tint: [Theme.cardElevated, Theme.card],
            appSize: 0,
            dataSize: 0,
            lastUsed: "—",
            isReal: true,
            hasKnownSize: false
        )
    }

    private static func makeSelfApp() -> AppItem {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "This App"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "1.0"

        return AppItem(
            id: "self",
            bundleID: Bundle.main.bundleIdentifier,
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
