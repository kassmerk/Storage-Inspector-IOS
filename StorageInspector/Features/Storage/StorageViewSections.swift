import SwiftUI

/// The sections of the Storage screen, kept in a separate file to keep `StorageView` readable.
extension StorageView {
    var thisAppCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                AppIconView(symbol: store.selfApp.symbol, tint: store.selfApp.tint, size: 52)

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
            Text("Applications")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("\(visibleApps.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.cardElevated))

            Spacer()

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
                    AppRowView(app: app, unit: unit)
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

    var emptySearchCard: some View {
        EmptyStateCard(
            symbol: "magnifyingglass",
            title: "No applications found",
            message: search.isEmpty
                ? "Demo data is turned off. Enable it in Settings to see the sample list."
                : "Nothing matches “\(search)”."
        )
    }

    var searchBar: some View {
        SearchField(placeholder: "Applications", text: $search)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Theme.background)
    }

    var footnote: some View {
        Text("iOS does not allow one app to read the storage used by other apps, so the list above is a demo dataset. Device capacity, this app's own sizes and the file browser are measured for real.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
