import SwiftUI

/// Top cards of the Settings screen.
extension SettingsView {
    var supportCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.pink)

            Text("Support Storage Inspector")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    "sparkles",
                    tint: Theme.accent,
                    title: "Tell your friends",
                    subtitle: "Share the app with someone who keeps running out of space."
                )
                featureRow(
                    "checkmark.seal",
                    tint: Theme.accent,
                    title: "No ads, no tracking",
                    subtitle: "Everything is measured on device. Nothing is uploaded anywhere."
                )
                featureRow(
                    "ladybug",
                    tint: Theme.accent,
                    title: "Report a bug",
                    subtitle: "Found something broken? A short message is enough to get it fixed."
                )
            }
            .padding(.top, 4)

            ShareLink(item: "Storage Inspector — a clean storage viewer for iPhone.") {
                Text("Share App")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(PressableCardStyle())
        }
        .cardStyle(padding: 20)
    }

    var preferencesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("Demo applications")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Toggle("", isOn: $showDemoApps)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            .padding(.vertical, 10)

            Separator(leading: 0)

            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("Installed apps")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Toggle("", isOn: $useInstalledApps)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .disabled(!InstalledAppsProvider.isAvailable)
            }
            .padding(.vertical, 10)
            .onChange(of: useInstalledApps) { enabled in
                if enabled {
                    store.loadInstalledApps(force: true)
                }
            }

            noteText(installedAppsNote)

            Separator(leading: 0)

            HStack(spacing: 12) {
                Image(systemName: "ruler.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                Text("Size unit")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Picker("", selection: $unitRaw) {
                    ForEach(SizeUnit.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.secondaryLabel)
            }
            .padding(.vertical, 6)

            Separator(leading: 0)

            Button {
                store.refresh()
            } label: {
                rowLabel("arrow.clockwise", tint: Theme.blue, title: "Refresh measurements", chevron: false)
            }
            .buttonStyle(PressableCardStyle())

            Separator(leading: 0)

            Button {
                store.restoreDemoApps()
            } label: {
                rowLabel("arrow.uturn.backward", tint: Theme.blue, title: "Restore demo list", chevron: false)
            }
            .buttonStyle(PressableCardStyle())
        }
        .cardStyle(padding: 16)
    }

    /// Explains the private-API switch, including why it may be disabled.
    var installedAppsNote: String {
        if let reason = InstalledAppsProvider.unavailableReason {
            return reason + " The demo list stays in use."
        }

        var text = "Lists the apps really installed on this iPhone, with their real icons, read through the private LSApplicationWorkspace API. Sideloaded builds only — a future iOS may close it, and the sizes stay hidden because iOS keeps them private."
        if !InstalledAppsProvider.iconsAvailable {
            text += " This iOS build does not expose the private icon lookup, so the tiles fall back to the App Store artwork."
        }
        return text
    }
}
