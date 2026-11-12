import SwiftUI

/// "About" card plus the small row builders shared by the Settings cards.
extension SettingsView {
    var aboutCard: some View {
        VStack(spacing: 0) {
            Button {
                showAbout = true
            } label: {
                rowLabel("info.circle.fill", tint: Theme.accent, title: "About Storage Inspector", chevron: true)
            }
            .buttonStyle(PressableCardStyle())

            Separator(leading: 0)

            if let mail = URL(string: "mailto:feedback@example.com?subject=Storage%20Inspector") {
                Link(destination: mail) {
                    rowLabel("paperplane.fill", tint: Theme.blue, title: "Send Feedback", chevron: true)
                }
                .buttonStyle(PressableCardStyle())
            }

            Separator(leading: 0)

            rowLabel(
                "number.square.fill",
                tint: Theme.secondaryLabel,
                title: "Version",
                detail: Formatters.version(),
                chevron: false
            )
        }
        .cardStyle(padding: 16)
    }

    var footnote: some View {
        Text("Device capacity and this app's own sizes are read from the file system. Sizes of other apps are a demo dataset, because iOS keeps them private.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    func featureRow(_ symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    func rowLabel(
        _ symbol: String,
        tint: Color,
        title: String,
        detail: String? = nil,
        chevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26)

            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if let detail = detail {
                Text(detail)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondaryLabel)
            }

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
