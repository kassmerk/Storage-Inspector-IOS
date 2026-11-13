import SwiftUI

enum StorageRoute: Hashable {
    case app(AppItem)
    case files(title: String, url: URL)
}

struct StorageView: View {
    /// Where the rows on screen come from. The screen has three real sources and one demo one, and
    /// it says which is in use instead of blending them: that is how fourteen demo rows stopped
    /// looking like the apps on this iPhone.
    enum ListSource {
        /// The LaunchServices list: every installed app, with sizes. Only privileged installs.
        case installed
        /// The list the user imported from a computer: every app the text named, with the sizes
        /// that text carried. On iOS 26 this is the only complete list — see `AppSchemeProbe`.
        case imported
        /// The URL-scheme probe: apps that are really installed, no sizes. The sandboxed case.
        case detected
        /// The demo dataset, only when the Settings switch is on.
        case demo
        /// Nothing to show.
        case none
    }

    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    /// Off by default: on iOS 26 the demo rows used to be what a Feather-signed install showed,
    /// which read as "these are your apps". Demo data is now an explicit preview.
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = false

    /// The icon of every row: the icon of the installed app, a hand-cut PNG from the bundle,
    /// or the official App Store artwork.
    @StateObject var iconLoader = AppIconLoader()

    @State var path: [StorageRoute] = []
    /// The sheet that reads an app list from a computer: the only way to see every app on iOS 26.
    @State var showImportSheet = false
    @State var search: String = ""
    @State var sortMode: SizeSortMode = .name
    /// The header shows a magnifier instead of a permanently pinned search field: the list is the
    /// screen, and the field only appears when it is asked for.
    @State var isSearchVisible = false
    @FocusState var searchFocused: Bool

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    /// The apps really installed on this iPhone are the list. The demo dataset is only the
    /// fallback for the builds where the private API is gone — it used to be the other way round,
    /// which is why the screen showed fourteen made-up rows instead of the apps on the device.
    var usesInstalledApps: Bool { InstalledAppsProvider.isAvailable }

    /// The demo dataset is only shown when the scan has nothing to offer: while it is still
    /// running the list stays empty (a flash of fake numbers would be worse), and when it comes
    /// back empty or unsupported the probe — or the demo rows, if switched on — step in.
    var showsDemoFallback: Bool {
        guard usesInstalledApps else { return true }

        switch store.installedState {
        case .ready, .idle, .loading: return false
        case .empty, .unavailable: return true
        }
    }

    /// Which source the rows below the header come from. An imported list wins over the probe: it
    /// is the only source that can hold every app, so once it exists the screen shows it instead of
    /// the handful of schemes iOS answered.
    var listSource: ListSource {
        if usesInstalledApps && !showsDemoFallback { return .installed }
        if !store.importedApps.isEmpty { return .imported }
        if !store.detectedApps.isEmpty { return .detected }
        return showDemoApps ? .demo : .none
    }

    /// The rows on screen: the apps really installed on this iPhone, the imported list, the apps the
    /// probe confirmed, or the demo dataset when it is switched on.
    var allApps: [AppItem] {
        switch listSource {
        case .installed: return store.installedApps
        case .imported:
            // The imported list is the complete one, but the probe can still know an app the text
            // missed (a sideloaded build, a reinstall after the list was made). Appending those
            // rows keeps the screen complete instead of dropping what iOS itself confirmed.
            let importedIDs = Set(store.importedApps.map { $0.id })
            let importedNames = Set(store.importedApps.map { ImportedApp.key($0.name) })
            let extra = store.detectedApps.filter { app in
                !importedIDs.contains(app.id) && !importedNames.contains(ImportedApp.key(app.name))
            }
            return store.importedApps + extra
        case .detected: return store.detectedApps
        case .demo: return store.apps
        case .none: return []
        }
    }

    /// How many rows on screen came from the probe instead of the imported text. Only the imported
    /// mode can have them: the text is a snapshot, and an app installed after it was made is missing
    /// from it until the next import. The footnote prints both numbers, so a short list is explained
    /// instead of looking like lost rows.
    var probedExtraCount: Int {
        guard case .imported = listSource else { return 0 }
        return max(0, allApps.count - store.importedApps.count)
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

                        if isSearchVisible {
                            searchRow
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if case .detected = listSource {
                            importHintCard
                                .padding(.horizontal, 16)
                        }

                        if visibleApps.isEmpty {
                            emptySearchCard
                                .padding(.horizontal, 16)

                            if search.isEmpty && showsImportButton {
                                importListButton
                                    .padding(.horizontal, 16)
                            }
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
        .sheet(isPresented: $showImportSheet) {
            ImportAppsView()
                .environmentObject(store)
        }
        .onChange(of: showDemoApps) { _ in loadIcons() }
        .onChange(of: store.importedApps) { _ in
            // The imported rows are the only source that can hold the whole list, and their icons
            // are looked up by bundle id, so the loader has to see them once the list changes.
            iconLoader.forget()
            loadIcons()
        }
        .onChange(of: store.detectedApps) { _ in
            // The probe list arrives on the main thread right after the first pass; its icons come
            // from the App Store artwork, so the loader has to look at the new rows once more.
            iconLoader.forget()
            loadIcons()
        }
        .onChange(of: store.installedApps) { _ in
            // The installed list arrives after the first pass, and only then can the real Home
            // Screen icons be read. Forgetting the marks makes the next pass resolve once more.
            iconLoader.forget()
            loadIcons()
        }
    }

    /// Re-reads the numbers, the installed apps, the imported list, the probed apps and the icons.
    func reload() {
        store.refresh()
        store.loadInstalledApps()
        store.loadImportedApps()
        store.loadDetectedApps()
        loadIcons()
    }

    /// Resolves the icons of the rows that are on screen right now.
    func loadIcons() {
        // Whenever iOS still answers the private icon lookup it is tried first, for the demo
        // rows as well: the real Home Screen icon beats a download.
        iconLoader.load(allApps + [store.selfApp], deviceIcons: InstalledAppsProvider.iconsAvailable)
    }
}
