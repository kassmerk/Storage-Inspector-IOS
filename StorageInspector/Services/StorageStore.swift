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
    /// Apps the URL-scheme probe confirmed (`AppSchemeProbe`). This is the only list a normally
    /// signed app can get on iOS builds that keep LaunchServices closed — it is a real answer, just
    /// for 44 hand-picked apps and without sizes.
    @Published private(set) var detectedApps: [AppItem] = []
    /// The list the user imported from a computer (`ImportedAppsStore` + `AppListParser`). This is
    /// the only source that can show *every* app on iOS 26: a sandboxed build cannot read the
    /// installed-app list, so the list has to be produced where iOS allows it and brought over.
    @Published private(set) var importedApps: [AppItem] = []
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

    /// Removes a row from whichever list it belongs to. Nothing on the iPhone is ever touched: the
    /// demo dataset, the imported list and the probe's rows are all only this app's own view.
    func remove(_ app: AppItem) {
        apps.removeAll { $0.id == app.id }

        if importedApps.contains(where: { $0.id == app.id }) {
            importedApps = ImportedAppsStore.remove(id: app.id).map(StorageStore.makeImportedApp)
        }
    }

    func restoreDemoApps() {
        apps = DemoCatalog.apps
    }

    /// Reads the list of really installed apps through the private API. The scan is cached for
    /// the session: pass `force: true` to repeat it (the Settings switch does that).
    ///
    /// `SettingsKeys.showHiddenApps` decides whether Apple's hidden daemons are listed as well; it
    /// is read here, not passed in, so the Settings toggle only has to rescan.
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
        let includeHidden = UserDefaults.standard.bool(forKey: SettingsKeys.showHiddenApps)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = InstalledAppsProvider.loadApps(includeHidden: includeHidden)
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

    /// Asks the URL-scheme probe which apps of its fixed list are on this device.
    ///
    /// Runs on the main thread on purpose: `canOpenURL` is a UIKit call, and the 44 synchronous
    /// checks finish in milliseconds — a background hop would only add a flicker. The result is a
    /// list of apps that are really installed; only their sizes stay unknown.
    func loadDetectedApps() {
        detectedApps = AppSchemeProbe.detect()
    }

    /// Reads the saved imported list (`ImportedAppsStore`) into the rows the Storage screen shows.
    func loadImportedApps() {
        importedApps = ImportedAppsStore.load().map(StorageStore.makeImportedApp)
    }

    /// Parses the text the user pasted or picked, merges it into the saved list and republishes the
    /// rows. The parse result comes back so the import screen can say how many apps were read and
    /// how many lines it had to skip.
    @discardableResult
    func importApps(from text: String) -> AppListParser.Result {
        let result = AppListParser.parse(text)
        guard !result.apps.isEmpty else { return result }

        importedApps = ImportedAppsStore.merge(result.apps).map(StorageStore.makeImportedApp)
        return result
    }

    /// Drops every imported row. Nothing else on the device is affected.
    func clearImportedApps() {
        importedApps = ImportedAppsStore.clear().map(StorageStore.makeImportedApp)
    }

    /// One row per installed app. The name, the version and the icon always come from iOS; the two
    /// sizes come from the private disk-usage getters of `LSApplicationProxy`, so they are real
    /// numbers when the system answers and a dash when it hides them.
    private static func makeInstalledApp(_ app: InstalledAppsProvider.InstalledApp) -> AppItem {
        AppItem(
            id: app.bundleID,
            bundleID: app.bundleID,
            name: app.name,
            developer: app.developer,
            version: app.version,
            symbol: "app.dashed",
            tint: [Theme.cardElevated, Theme.card],
            appSize: app.appSize ?? 0,
            dataSize: app.dataSize ?? 0,
            lastUsed: "—",
            isReal: true,
            hasKnownAppSize: app.appSize != nil,
            hasKnownDataSize: app.dataSize != nil
        )
    }

    /// One imported row: the name and the version come from the imported text, and so does the
    /// size — when the text had one. A row without a number keeps its dash instead of a fake zero,
    /// and `isImported` lets the detail screen explain where the numbers came from.
    private static func makeImportedApp(_ app: ImportedApp) -> AppItem {
        AppItem(
            id: app.id,
            bundleID: app.bundleID,
            name: app.name,
            developer: "Imported list",
            version: app.version ?? "—",
            symbol: "app.dashed",
            tint: [Theme.cardElevated, Theme.card],
            appSize: app.appSize ?? 0,
            dataSize: app.dataSize ?? 0,
            lastUsed: "—",
            isReal: true,
            hasKnownAppSize: app.appSize != nil,
            hasKnownDataSize: app.dataSize != nil,
            isImported: true
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
