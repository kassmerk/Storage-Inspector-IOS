import SwiftUI

/// Description sheet opened from "About Storage Inspector".
struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        AppIconView(
                            symbol: "internaldrive.fill",
                            tint: [Theme.accent, Theme.indigo],
                            size: 62,
                            cornerRadius: 15
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Storage Inspector")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Version \(Formatters.version())")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.secondaryLabel)
                        }

                        Spacer()
                    }

                    Text("Storage Inspector shows how much space your iPhone has, breaks it down by category and lets you walk through this app's own file container.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryLabel)

                    Text("Real: total capacity, free space, the size of this app's bundle and data container, and every file in the browser — all of it is measured from the file system.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryLabel)

                    Text("Demo: the per-app sizes. iOS sandboxes apps, so a third-party app cannot read another app's container or bundle size. The list exists to show the interface and can be switched off in Settings.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AboutSheet_Previews: PreviewProvider {
    static var previews: some View {
        AboutSheet()
    }
}
