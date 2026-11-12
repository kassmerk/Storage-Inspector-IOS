import SwiftUI
import UIKit

/// One row of the applications list: icon, name, last used, size, chevron.
struct AppRowView: View {
    let app: AppItem
    let unit: SizeUnit
    /// The resolved icon (device, bundled or store artwork); `nil` keeps the placeholder.
    var artwork: UIImage? = nil

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(symbol: app.symbol, tint: app.tint, size: 52, artwork: artwork)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Formatters.size(app.totalSize, known: app.hasKnownSize, unit: unit))
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondaryLabel)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    /// Apps read from the device have no "last used" date, so the vendor is shown instead.
    private var subtitle: String {
        app.hasKnownSize ? "Last used: \(app.lastUsed)" : app.developer
    }
}

struct AppRowView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ForEach(Array(DemoCatalog.apps.prefix(3)), id: \.id) { app in
                    AppRowView(app: app, unit: .automatic)
                    Separator(leading: 82)
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }
}
