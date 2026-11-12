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
            installedAppsRow

            if InstalledAppsProvider.isAvailable {
                Separator(leading: 0)
                hiddenAppsRow
            }

            noteText(installedAppsNote)

            if !InstalledAppsProvider.isAvailable {
                Separator(leading: 0)
                demoAppsRow
            }

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

            if !InstalledAppsProvider.isAvailable {
                Separator(leading: 0)

                Button {
                    store.restoreDemoApps()
                } label: {
                    rowLabel("arrow.uturn.backward", tint: Theme.blue, title: "Restore demo list", chevron: false)
                }
                .buttonStyle(PressableCardStyle())
            }
        }
        .cardStyle(padding: 16)
    }

    /// Status row of the installed-apps scan: how many apps it found and a button to scan again.
    /// The Storage screen always shows this scan now; the demo dataset is only the fallback for
    /// the iOS builds that no longer answer the private API.
    var installedAppsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)

            Text("Installed apps")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if case .loading = store.installedState {
                ProgressView()
                    .tint(Theme.secondaryLabel)
            } else {
                Text(installedCountText)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }

            Button {
                store.loadInstalledApps(force: true)
            } label: {
                Text("Rescan")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.blue)
            }
            .buttonStyle(PressableCardStyle())
            .disabled(!InstalledAppsProvider.isAvailable)
        }
        .padding(.vertical, 10)
    }

    /// "23 found" / "None" / "Unavailable" — the state of the last scan.
    var installedCountText: String {
        guard InstalledAppsProvider.isAvailable else { return "Unavailable" }

        switch store.installedState {
        case .ready: return "\(store.installedApps.count) found"
        case .empty: return "None"
        case .unavailable: return "Unavailable"
        case .idle, .loading: return "—"
        }
    }

    /// "Include hidden system apps" — the only filter the scan applies to Apple's entries.
    /// iPhone Storage never shows these daemons, so the toggle is off by default.
    var hiddenAppsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Show hidden apps")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Text("Apple's system services and helpers without an icon.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryLabel)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $showHiddenApps)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.vertical, 10)
    }

    /// Only rendered when the private API is gone: the demo dataset then becomes the list.
    var demoAppsRow: some View {
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
    }

    /// Explains where the list and the sizes come from, including why the scan may be unavailable.
    var installedAppsNote: String {
        if let reason = InstalledAppsProvider.unavailableReason {
            return reason + " The demo list stays in use."
        }

        var text = "The Storage screen lists every app installed on this iPhone, read through the private LSApplicationWorkspace API — sideloaded builds only. A second pass walks the app bundle folders, which is how hidden TrollStore installs still get a row and how a size can be measured when the system refuses one. The sizes themselves come from the same proxy (`staticDiskUsage` and `dynamicDiskUsage`); where this iOS build answers 0, the row shows a dash instead of a guess."
        if !InstalledAppsProvider.iconsAvailable {
            text += " This iOS build does not expose the private icon lookup, so the tiles fall back to the App Store artwork."
        }

        switch store.installedState {
        case .ready:
            text += " The last scan found \(store.installedApps.count) apps"
            text += showHiddenApps ? ", hidden system entries included." : ", with hidden system entries filtered out."
        case .empty:
            text += " The last scan found no apps at all."
        case .idle, .loading, .unavailable:
            break
        }
        return text
    }
}
