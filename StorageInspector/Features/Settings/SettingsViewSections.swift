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
}
