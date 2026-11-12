import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StorageStore
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue
    @AppStorage(SettingsKeys.showDemoApps) var showDemoApps: Bool = true

    @State var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle(title: "Settings")
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    supportCard
                    preferencesCard
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
