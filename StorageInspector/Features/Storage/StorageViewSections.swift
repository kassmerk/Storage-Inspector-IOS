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

    var applicationsHeader: some View {
        HStack(spacing: 10) {
            Text(showsDemoFallback ? "Applications" : "Installed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("\(visibleApps.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.cardElevated))

            Spacer()

            if usesInstalledApps {
                if case .loading = store.installedState {
                    ProgressView()
                        .tint(Theme.secondaryLabel)
                } else {
                    Button {
                        store.loadInstalledApps(force: true)
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
                    message: reason + " The demo list is shown instead."
                )
            case .empty:
                EmptyStateCard(
                    symbol: "square.grid.2x2",
                    title: "No apps found",
                    message: "iOS returned an empty list through the private API. Pull the refresh button next to the title to scan again."
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
                title: "Demo list is hidden",
                message: "Demo data is turned off. Enable it in Settings until this iOS build exposes the installed apps again."
            )
        }
    }

    /// Search pinned right above the tab bar, shaped like the App Library field: a capsule with a
    /// magnifier on the left, plus a separate round button on the right that clears the query and
    /// drops the keyboard (the small “×” inside the field only clears the text).
    var searchBar: some View {
        HStack(spacing: 10) {
            SearchField(placeholder: "Applications", text: $search)

            if !search.isEmpty {
                Button {
                    search = ""
                    hideKeyboard()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.cardElevated))
                }
                .buttonStyle(PressableCardStyle())
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.15), value: search.isEmpty)
    }

    var footnote: some View {
        Text(footnoteText)
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    var footnoteText: String {
        if !showsDemoFallback {
            let measured = visibleApps.contains { $0.hasKnownSize }
            if measured {
                return "The list, the icons and the sizes come from iOS itself: the apps through the private LSApplicationWorkspace API, the numbers through its disk-usage getters. A row that shows a dash is one this iOS build would not measure — nothing here is invented. Settings › Show hidden apps adds Apple's hidden system services to the list. Device capacity, this app's own sizes and the file browser are measured for real."
            }
            return "The list and the icons come from iOS itself through the private LSApplicationWorkspace API, which only works in a sideloaded app. This iOS build reports no size for other apps, so those rows show a dash instead of a made-up number. Device capacity, this app's own sizes and the file browser are measured for real."
        }
        return "The list below is the demo dataset that ships with the app: this iOS build either no longer exposes the installed apps or the scan came back empty. The icons are still the real ones: the icon of the app installed on this device, a bundled PNG, or the official App Store artwork. Device capacity, this app's own sizes and the file browser are measured for real."
    }
}
