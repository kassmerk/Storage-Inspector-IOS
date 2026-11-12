import SwiftUI
import UIKit

/// Detail screen in the style of the iOS "iPhone Storage › App" page, with an extra
/// "View Files" shortcut to the app sandbox browser.
struct AppDetailView: View {
    let app: AppItem
    /// The resolved icon (device, bundled or store artwork) for the header tile.
    var artwork: UIImage? = nil

    @EnvironmentObject var store: StorageStore
    @Environment(\.dismiss) var dismiss
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue

    @State var showDeleteDialog = false

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: app.name) { dismiss() }

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    if showsSandboxLink {
                        viewFilesButton
                    }
                    actions
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "Delete “\(app.name)” from the list?",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete entry", role: .destructive) {
                store.remove(app)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only the demo entry is removed. Nothing is deleted from your iPhone.")
        }
    }

    /// The sandbox browser can only show *this* app's files, so the shortcut is hidden for the
    /// apps that really belong to someone else on the device. The demo rows keep it as a preview.
    private var showsSandboxLink: Bool {
        !app.isReal || app.id == "self"
    }

    var headerCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIconView(
                    symbol: app.symbol,
                    tint: app.tint,
                    size: 62,
                    cornerRadius: 15,
                    artwork: artwork
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(app.version)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryLabel)
                    Text(app.developer)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryLabel)
                }

                Spacer(minLength: 8)
            }
            .padding(.bottom, 14)

            Separator(leading: 0)
            InfoRow(title: "App Size", value: Formatters.size(app.appSize, known: app.hasKnownAppSize, unit: unit))
            Separator(leading: 0)
            InfoRow(title: "Documents & Data", value: Formatters.size(app.dataSize, known: app.hasKnownDataSize, unit: unit))
            Separator(leading: 0)
            InfoRow(title: "Total", value: Formatters.size(app.totalSize, known: app.hasKnownSize, unit: unit))
        }
        .cardStyle(padding: 18)
    }

    var viewFilesButton: some View {
        NavigationLink(value: StorageRoute.files(title: app.name, url: SandboxFiles.documentsURL)) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                Text("View Files")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    var actions: some View {
        VStack(spacing: 10) {
            if app.id == "self" {
                ActionButton(title: "Refresh Size", kind: .standard) {
                    store.refresh()
                }
                caption("Recalculated from this app's bundle and data container.")
            } else if app.isReal {
                caption(installedCaption)
            } else {
                ActionButton(title: "Offload App") { }
                caption("Preview only: iOS does not let an app offload other apps. On a real iPhone this lives in Settings › General › iPhone Storage.")

                ActionButton(title: "Delete App", kind: .destructive) {
                    showDeleteDialog = true
                }
                caption("Removes the entry from the demo list. Your iPhone storage is not touched.")
            }
        }
    }

    /// What the numbers above this caption mean for a row that came from the installed-apps scan.
    private var installedCaption: String {
        if app.hasKnownSize {
            return "Sizes read from iOS itself through the private LSApplicationWorkspace disk-usage getters. A dash in one of the rows means that build hides that half of the footprint."
        }
        return "This row comes from iOS itself (private installed-apps API): the name, the version and the icon are real, but this iOS build does not report how much space the app takes, so the numbers above show a dash. iOS also does not let one app delete or offload another."
    }

    func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct AppDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AppDetailView(app: DemoCatalog.apps[2])
                .environmentObject(StorageStore())
        }
        .preferredColorScheme(.dark)
    }
}
