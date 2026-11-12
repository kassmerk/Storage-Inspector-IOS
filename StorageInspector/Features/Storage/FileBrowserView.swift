import SwiftUI

/// Real file browser for the app's own sandbox (the "View Files" destination).
struct FileBrowserView: View {
    let title: String
    let url: URL

    @Environment(\.dismiss) var dismiss
    @AppStorage(SettingsKeys.sizeUnit) var unitRaw: String = SizeUnit.automatic.rawValue

    @State var entries: [SandboxEntry] = []
    @State var totalSize: Int64 = 0
    @State var pendingDelete: SandboxEntry? = nil
    @State var errorText: String? = nil

    var unit: SizeUnit { SizeUnit(rawValue: unitRaw) ?? .automatic }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: title) { dismiss() }

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if entries.isEmpty {
                        EmptyStateCard(
                            symbol: "folder",
                            title: "No files here",
                            message: "The folder is empty. Add a few sample files to see how sizes are measured.",
                            actionTitle: "Add Sample Files"
                        ) {
                            createSamples()
                        }
                    } else {
                        entriesCard
                    }

                    if let errorText = errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: reload)
        .alert(
            "Delete?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) { delete(entry) }
            Button("Cancel", role: .cancel) { }
        } message: { entry in
            Text("“\(entry.name)” will be removed from this app's container.")
        }
    }

    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.bytes(totalSize, unit: unit))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.cardElevated))
            }

            Text(SandboxFiles.displayPath(for: url))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.tertiaryLabel)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 18)
    }

    var entriesCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if entry.isDirectory {
                    NavigationLink(value: StorageRoute.files(title: entry.name, url: entry.url)) {
                        row(for: entry, showsChevron: true)
                    }
                    .buttonStyle(PressableCardStyle())
                } else {
                    row(for: entry, showsChevron: false)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = entry
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                if index < entries.count - 1 {
                    Separator(leading: 60)
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.card)
        )
    }
}
