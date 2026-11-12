import SwiftUI

enum StorageRoute: Hashable {
    case app(AppItem)
    case files(title: String, url: URL)
}

struct StorageView: View {
    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = true

    @State var path: [StorageRoute] = []
    @State var search: String = ""
    @State var sortMode: SizeSortMode = .size

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    var allApps: [AppItem] { showDemoApps ? store.apps : [] }

    var applicationsBytes: Int64 { store.selfApp.totalSize + (showDemoApps ? store.demoTotal : 0) }

    var visibleApps: [AppItem] {
        let filtered = search.isEmpty
            ? allApps
            : allApps.filter { $0.name.localizedCaseInsensitiveContains(search) }

        switch sortMode {
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
                    AppDetailView(app: app)
                case .files(let title, let url):
                    FileBrowserView(title: title, url: url)
                }
            }
        }
        .onAppear { store.refresh() }
    }
}
