import Foundation
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

            Separator(leading: 0)
            importAppsRow

            if InstalledAppsProvider.isAvailable {
                Separator(leading: 0)
                hiddenAppsRow
            }

            noteText(installedAppsNote)

            if store.installedApps.isEmpty {
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

    /// The only way to see *every* app on iOS 26: a list built where iOS allows it. The row opens
    /// `ImportAppsView`, and its subtitle always says how many rows are in the list right now.
    var importAppsRow: some View {
        Button {
            showImport = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import app list")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                    Text(importAppsNote)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    var importAppsNote: String {
        store.importedApps.isEmpty
            ? "The only way to list every app on iOS 26: a list from your computer."
            : "\(store.importedApps.count) apps imported from your computer."
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

    /// The demo preview: off by default, and named as demo data. It used to be the fallback that
    /// silently filled the Storage screen with fourteen made-up rows, which read as "these are the
    /// apps on this iPhone" — the screen now asks for it explicitly instead.
    var demoAppsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Demo applications")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                Text("Sample rows, not the apps on this iPhone.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryLabel)
            }

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
            return reason + " The URL-scheme probe below is the only list left for this build."
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
            text += " The last scan found no apps at all: a class that answers while every list comes back with zero entries is what a normally signed install (Feather, a certificate, the App Store) gets on this iOS build — the LaunchServices database is closed to it, and only the platform-application entitlement of a TrollStore or jailbreak install opens it, which iOS 26 does not have. The Storage screen therefore shows what the URL-scheme probe confirmed: \(store.detectedApps.count) apps, checked one by one. Their sizes are never reported to a sandboxed app, and an app that registers none of the \(AppSchemeProbe.candidates.count) probed schemes cannot be seen this way."
        case .idle, .loading, .unavailable:
            break
        }
        return text
    }

    /// The report that answers "why is the list empty": what the LaunchServices class, each list
    /// selector and each bundle folder answered on *this* install. A class that was found with all
    /// counts at 0 is a blocked sandbox, a class that is missing is a renamed API — completely
    /// different problems, and the list alone cannot tell them apart.
    var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)

                Text("Diagnostics")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Button {
                    reloadDiagnostics()
                } label: {
                    Text(diagnosticsRunning ? "Reading…" : "Run again")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.blue)
                }
                .buttonStyle(PressableCardStyle())
                .disabled(diagnosticsRunning)
            }

            if diagnosticsRows.isEmpty {
                Text(diagnosticsRunning ? "Asking the private API…" : "No report yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiaryLabel)
            } else {
                ForEach(Array(diagnosticsRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 10) {
                        Text(row.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryLabel)
                            .frame(width: 128, alignment: .leading)

                        Text(row.value)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("`not readable` on a bundle folder and `0 entries` on every selector mean the same thing: this build is not allowed to see the other apps. `Scheme probes` is how many apps are asked about, `Scheme matches` is how many iOS confirmed — those matches are the `Detected apps` rows on the Storage screen. `0 declared in Info.plist` means the scheme list is missing from this build, and then only the per-bundle lookup channel can answer.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
        }
        .cardStyle(padding: 16)
    }

    /// Runs the report off the main thread: it lists the bundle folders and runs the full scan.
    func reloadDiagnostics() {
        guard !diagnosticsRunning else { return }

        diagnosticsRunning = true
        let includeHidden = UserDefaults.standard.bool(forKey: SettingsKeys.showHiddenApps)

        DispatchQueue.global(qos: .userInitiated).async {
            let rows = InstalledAppsProvider.diagnostics(includeHidden: includeHidden)

            DispatchQueue.main.async {
                // The probe rows are added here and not on the background queue: `canOpenURL` is a
                // UIKit call. These two rows are what explains an empty list on a signed install.
                var report = rows
                report.append(
                    InstalledAppsProvider.Diagnostic(
                        title: "Scheme probes",
                        value: "\(AppSchemeProbe.candidates.count) candidates, \(AppSchemeProbe.declaredSchemes.count) declared in Info.plist"
                    )
                )
                report.append(
                    InstalledAppsProvider.Diagnostic(
                        title: "Scheme matches",
                        value: "\(AppSchemeProbe.detect().count) apps confirmed on this device"
                    )
                )

                diagnosticsRows = report
                diagnosticsRunning = false
            }
        }
    }
}
