import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = false
    @AppStorage(SettingsKeys.showHiddenApps) var showHiddenApps: Bool = false

    @State var showAbout = false
    /// Sheet with the app-list import: the only way to see every app on iOS 26.
    @State var showImport = false

    /// The report of the Diagnostics card: what the private API answered on this install.
    @State var diagnosticsRows: [InstalledAppsProvider.Diagnostic] = []
    @State var diagnosticsRunning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle(title: "Settings")
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    supportCard
                    preferencesCard
                    diagnosticsCard
                    AppIconCard()
                    aboutCard
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAbout) {
                AboutSheet()
            }
            .sheet(isPresented: $showImport) {
                ImportAppsView()
                    .environmentObject(store)
            }
            .task {
                // The report is what tells an empty list apart from a blocked one, so it is read
                // once the screen appears instead of waiting for a tap.
                reloadDiagnostics()
            }
            .onChange(of: showHiddenApps) { _ in
                // The filter lives in the provider, so the list has to be read again.
                store.loadInstalledApps(force: true)
                reloadDiagnostics()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(StorageStore())
            .preferredColorScheme(.dark)
    }
}
