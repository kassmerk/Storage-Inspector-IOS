import SwiftUI

enum StorageRoute: Hashable {
    case app(AppItem)
    case files(title: String, url: URL)
}

struct StorageView: View {
    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = true
    @AppStorage(SettingsKeys.useInstalledApps) var useInstalledApps: Bool = false

    /// The icon of every row: the icon of the installed app, a hand-cut PNG from the bundle,
    /// or the official App Store artwork.
    @StateObject var iconLoader = AppIconLoader()

    @State var path: [StorageRoute] = []
    @State var search: String = ""
    @State var sortMode: SizeSortMode = .size

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    /// The rows on screen: the apps really installed on this iPhone, or the demo dataset.
    var allApps: [AppItem] {
        if useInstalledApps { return store.installedApps }
        return showDemoApps ? store.apps : []
    }

    var applicationsBytes: Int64 {
        store.selfApp.totalSize + allApps.reduce(0) { $0 + $1.totalSize }
    }

    /// iOS never reveals the size of the installed apps, so sorting by size makes no sense there.
    var effectiveSortMode: SizeSortMode { useInstalledApps ? .name : sortMode }

    var visibleApps: [AppItem] {
        let filtered = search.isEmpty
            ? allApps
            : allApps.filter { $0.name.localizedCaseInsensitiveContains(search) }

        switch effectiveSortMode {
        case .size:
            return filtered.sorted { $0.totalSize > $1.totalSize }
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
        .onChange(of: useInstalledApps) { _ in reload() }
        .onChange(of: showDemoApps) { _ in loadIcons() }
        .onChange(of: store.installedApps) { _ in loadIcons() }
    }

    /// Re-reads the numbers, the installed apps (when that mode is on) and the icons.
    func reload() {
        store.refresh()
        if useInstalledApps {
            store.loadInstalledApps()
        }
        loadIcons()
    }

    /// Resolves the icons of the rows that are on screen right now.
    func loadIcons() {
        // Whenever iOS still answers the private icon lookup it is tried first, for the demo
        // rows as well: the real Home Screen icon beats a download.
        iconLoader.load(allApps + [store.selfApp], deviceIcons: InstalledAppsProvider.iconsAvailable)
    }
}
