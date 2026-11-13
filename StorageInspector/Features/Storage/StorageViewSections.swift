import SwiftUI

/// The sections of the Storage screen, kept in a separate file to keep `StorageView` readable.
extension StorageView {
    var thisAppCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                AppIconView(
                    symbol: store.selfApp.symbol,
                    tint: store.selfApp.tint,
                    size: 52,
                    artwork: iconLoader.image(for: store.selfApp)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("This app")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Measured on this device")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryLabel)
                }

                Spacer(minLength: 8)

                Text(Formatters.bytes(store.selfApp.totalSize, unit: unit))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }

            NavigationLink(value: StorageRoute.files(title: "This App", url: SandboxFiles.documentsURL)) {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("View Files")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryLabel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cardElevated)
                )
            }
            .buttonStyle(PressableCardStyle())
        }
        .cardStyle(padding: 16)
    }

    /// Header title: which source the rows come from, spelled out instead of implied.
    var applicationsTitle: String {
        switch listSource {
        case .installed: return "Installed"
        case .imported: return "Imported list"
        case .detected: return "Detected apps"
        case .demo: return "Demo data"
        case .none: return "Applications"
        }
    }

    /// The refresh button re-runs both scanners, so it stays available for the probe as well.
    var showsRefreshButton: Bool {
        usesInstalledApps || AppSchemeProbe.isConfigured
    }

    /// The import button is offered wherever the list is not the full one: it is the only path that
    /// can put every app on the screen on iOS 26.
    var showsImportButton: Bool {
        switch listSource {
        case .installed, .demo: return false
        case .imported, .detected, .none: return true
        }
    }

    var applicationsHeader: some View {
        HStack(spacing: 10) {
            Text(applicationsTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("\(visibleApps.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.cardElevated))

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchVisible.toggle()
                }
                if !isSearchVisible {
                    search = ""
                    hideKeyboard()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSearchVisible ? Theme.blue : Theme.secondaryLabel)
                    .padding(4)
            }
            .buttonStyle(PressableCardStyle())

            Spacer()

            if showsImportButton {
                Button {
                    showImportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .padding(6)
                }
                .buttonStyle(PressableCardStyle())
            }

            if showsRefreshButton {
                if case .loading = store.installedState {
                    ProgressView()
                        .tint(Theme.secondaryLabel)
                } else {
                    Button {
                        store.loadInstalledApps(force: true)
                        store.loadDetectedApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.blue)
                            .padding(6)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }

            Button {
                sortMode = sortMode == .size ? .name : .size
            } label: {
                HStack(spacing: 5) {
                    Text(sortMode.title)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                }
                .font(.system(size: 17))
                .foregroundStyle(Theme.blue)
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    var appsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                NavigationLink(value: StorageRoute.app(app)) {
                    AppRowView(app: app, unit: unit, artwork: iconLoader.image(for: app))
                }
                .buttonStyle(PressableCardStyle())

                if index < visibleApps.count - 1 {
                    Separator(leading: 82)
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.card)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    var emptySearchCard: some View {
        if !search.isEmpty {
            EmptyStateCard(
                symbol: "magnifyingglass",
                title: "No applications found",
                message: "Nothing matches “\(search)”."
            )
        } else if usesInstalledApps {
            switch store.installedState {
            case .idle, .loading:
                EmptyStateCard(
                    symbol: "hourglass",
                    title: "Reading installed apps",
                    message: "Asking iOS for the apps on this iPhone, their sizes and their icons. This takes a second."
                )
            case .unavailable(let reason):
                EmptyStateCard(
                    symbol: "exclamationmark.triangle",
                    title: "Installed apps unavailable",
                    message: reason + " The URL-scheme probe below is used instead."
                )
            case .empty:
                EmptyStateCard(
                    symbol: "square.grid.2x2",
                    title: "No apps found",
                    message: "iOS answered the LaunchServices list with zero entries. That is exactly what a normally signed install gets on iOS 26: Feather, Xcode and the App Store issue a certificate, not the platform entitlement, so the LaunchServices database and every per-app size stay closed, and no code can open them. The rows below are the ones the URL-scheme probe could confirm; the Diagnostics card in Settings prints every count. To list every app instead of the probe's handful, import a list from a computer: the button below reads the output of ideviceinstaller or a CSV. For per-app sizes iOS keeps its own privileged screen: Settings > General > iPhone Storage."
                )
            case .ready:
                EmptyStateCard(
                    symbol: "magnifyingglass",
                    title: "No applications found",
                    message: "Nothing matches the current filter."
                )
            }
        } else {
            EmptyStateCard(
                symbol: "square.stack.3d.up",
                title: "No app list yet",
                message: "The LaunchServices scan found nothing, and the URL-scheme probe confirmed none of its \(AppSchemeProbe.candidates.count) candidates. On iOS 26 no sandboxed app can read the installed-app list, so the one way to see every app here is a list imported from a computer: the button below reads the output of ideviceinstaller or a CSV. Settings > Demo applications still shows the screen with sample data."
            )
        }
    }

    /// The one action that turns "no list" into "every app": opens the import sheet.
    var importListButton: some View {
        Button {
            showImportSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import app list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Paste or pick a list from your computer to see every app on this iPhone.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Search pinned right above the tab bar, shaped like the App Library field: a capsule with a
    /// magnifier on the left, plus a separate round button on the right that clears the query and
    /// drops the keyboard (the small “×” inside the field only clears the text).
    var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondaryLabel)

                TextField(
                    "",
                    text: $search,
                    prompt: Text("Search by name").foregroundColor(Theme.secondaryLabel)
                )
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { hideKeyboard() }
                .foregroundStyle(.white)

                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.tertiaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 17))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))

            Button {
                search = ""
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchVisible = false
                }
                hideKeyboard()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.blue)
            }
            .buttonStyle(PressableCardStyle())
        }
        .padding(.horizontal, 16)
        .onAppear {
            // The magnifier is a deliberate tap, so the field can open with the keyboard up.
            searchFocused = true
        }
    }

    /// Shown while the rows come from the URL-scheme probe: it can name an app but never measure
    /// it, and it only knows the schemes in `AppSchemeProbe`. The imported list is the complete
    /// one, so the action that fixes both problems sits right above the rows.
    var importHintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.yellow)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Not every app, and no sizes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("iOS 26 gives a sandboxed app neither the installed-app list nor a per-app size. These rows are the ones the URL-scheme probe confirmed, so their size stays a dash.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showImportSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Import the full list")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accent)
                )
            }
            .buttonStyle(PressableCardStyle())
        }
        .cardStyle(padding: 16)
    }

    var footnote: some View {
        Text(footnoteText)
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    var footnoteText: String {
        switch listSource {
        case .installed:
            let measured = visibleApps.contains { $0.hasKnownSize }
            if measured {
                return "The list, the icons and the sizes come from iOS itself: the apps through the private LSApplicationWorkspace API, the numbers through its disk-usage getters. A row that shows a dash is one this iOS build would not measure — nothing here is invented. Settings › Show hidden apps adds Apple's hidden system services to the list. Device capacity, this app's own sizes and the file browser are measured for real."
            }
            return "The list and the icons come from iOS itself through the private LSApplicationWorkspace API, which only answers a privileged install. This iOS build reports no size for other apps, so those rows show a dash instead of a made-up number. Device capacity, this app's own sizes and the file browser are measured for real."
        case .imported:
            var text = "These \(visibleApps.count) rows come from the list you imported from your computer, not from iOS: on this iPhone a sandboxed app cannot read the installed-app database at all, so a list produced where iOS does allow it (a paired Mac or PC) is the only complete one. Sizes are shown exactly as the imported text had them — a row without a number keeps its dash and nothing is estimated — and the icons are the official App Store artwork looked up by bundle id. To update the list, import again from the header button or Settings › Import app list; iOS keeps its own numbers in Settings › General › iPhone Storage. Device capacity, this app's own sizes and the file browser are measured for real."
            if probedExtraCount > 0 {
                text = "\(store.importedApps.count) of these rows came from your imported text, and \(probedExtraCount) more were confirmed by iOS after that text was made — those keep their dash, because iOS does not report another app's size to a sandboxed build. " + text
            }
            return text
        case .detected:
            return "These \(visibleApps.count) apps are really on this iPhone: iOS confirmed each one for the URL-scheme probe, and that probe can only ask about the \(AppSchemeProbe.candidates.count) apps listed in Services/AppSchemeProbe.swift (their schemes are in Resources/Info.plist — Apple allows 50 per app). An app that is not on that list, or that registers none of those schemes, cannot be seen this way, which is why this list is shorter than Settings › General › iPhone Storage; the import button puts the complete one on screen. Their sizes are not here either, because iOS never reports the size of another app to a sandboxed app — a dash there is the honest answer, not a missing feature. Device capacity, this app's own sizes and the file browser are measured for real."
        case .demo:
            return "These \(visibleApps.count) rows are the demo dataset that ships with the app, not the apps on this iPhone. It is switched on in Settings › Demo applications; the real scan found nothing, and the URL-scheme probe confirmed none of its candidates. The icons are still real: a PNG taken from the app bundle, the icon iOS draws on the Home Screen, or the official App Store artwork. Device capacity, this app's own sizes and the file browser are measured for real."
        case .none:
            return "Nothing to list yet: the LaunchServices scan found no apps, the URL-scheme probe confirmed none of its candidates, and the demo preview is off. Device capacity, this app's own sizes and the file browser are measured for real either way."
        }
    }
}
