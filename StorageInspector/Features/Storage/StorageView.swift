import SwiftUI

enum StorageRoute: Hashable {
    case app(AppItem)
    case files(title: String, url: URL)
}

struct StorageView: View {
    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = true

    /// The icon of every row: the icon of the installed app, a hand-cut PNG from the bundle,
    /// or the official App Store artwork.
    @StateObject var iconLoader = AppIconLoader()

    @State var path: [StorageRoute] = []
    @State var search: String = ""
    @State var sortMode: SizeSortMode = .name

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    /// The apps really installed on this iPhone are the list. The demo dataset is only the
    /// fallback for the builds where the private API is gone — it used to be the other way round,
    /// which is why the screen showed fourteen made-up rows instead of the apps on the device.
    var usesInstalledApps: Bool { InstalledAppsProvider.isAvailable }

    /// The demo dataset is only shown when the scan has nothing to offer: while it is still
    /// running the list stays empty (a flash of fake numbers would be worse), and when it comes
    /// back empty or unsupported the demo rows step in.
    var showsDemoFallback: Bool {
        guard usesInstalledApps else { return true }

        switch store.installedState {
        case .ready, .idle, .loading: return false
        case .empty, .unavailable: return true
        }
    }

    /// The rows on screen: the apps really installed on this iPhone, or the demo dataset.
    var allApps: [AppItem] {
        if usesInstalledApps && !showsDemoFallback { return store.installedApps }
        return showDemoApps ? store.apps : []
    }

    var applicationsBytes: Int64 {
        store.selfApp.totalSize + allApps.reduce(0) { $0 + $1.totalSize }
    }

    var visibleApps: [AppItem] {
        let filtered = search.isEmpty
            ? allApps
            : allApps.filter { app in
                app.name.localizedCaseInsensitiveContains(search)
                    || app.developer.localizedCaseInsensitiveContains(search)
                    || (app.bundleID?.localizedCaseInsensitiveContains(search) ?? false)
            }

        switch sortMode {
        case .size:
            return filtered.sorted { lhs, rhs in
                // Rows whose size iOS keeps private go last instead of pretending to be 0 MB.
                if lhs.hasKnownSize != rhs.hasKnownSize { return lhs.hasKnownSize }
                return lhs.totalSize > rhs.totalSize
            }
        case .name:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        ScreenTitle(title: "Storage", subtitle: "Device capacity and app sizes")
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        StorageSummaryCard(
                            capacity: store.capacity,
                            applicationsBytes: applicationsBytes,
                            unit: unit
                        )
                        .padding(.horizontal, 16)

                        thisAppCard
                            .padding(.horizontal, 16)

                        applicationsHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        if visibleApps.isEmpty {
                            emptySearchCard
                                .padding(.horizontal, 16)
                        } else {
                            appsCard
                        }

                        footnote
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                searchBar
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: StorageRoute.self) { route in
                switch route {
                case .app(let app):
                    AppDetailView(app: app, artwork: iconLoader.image(for: app))
                case .files(let title, let url):
                    FileBrowserView(title: title, url: url)
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: showDemoApps) { _ in loadIcons() }
        .onChange(of: store.installedApps) { _ in
            // The installed list arrives after the first pass, and only then can the real Home
            // Screen icons be read. Forgetting the marks makes the next pass resolve once more.
            iconLoader.forget()
            loadIcons()
        }
    }

    /// Re-reads the numbers, the installed apps and the icons.
    func reload() {
        store.refresh()
        store.loadInstalledApps()
        loadIcons()
    }

    /// Resolves the icons of the rows that are on screen right now.
    func loadIcons() {
        // Whenever iOS still answers the private icon lookup it is tried first, for the demo
        // rows as well: the real Home Screen icon beats a download.
        iconLoader.load(allApps + [store.selfApp], deviceIcons: InstalledAppsProvider.iconsAvailable)
    }
}
