import SwiftUI
import UniformTypeIdentifiers

/// Sheet that brings an app list over from a computer.
///
/// On iOS 26 the sandbox cannot read the installed-app list (see `AppSchemeProbe`), so the only way
/// to show *every* app is a list made where iOS does allow it: the `ideviceinstaller` output of a
/// paired Mac or PC, a CSV from a desktop tool, or a copy of Settings › General › iPhone Storage.
/// This screen reads any of them through `AppListParser` and keeps the result in
/// `ImportedAppsStore`.
struct ImportAppsView: View {
    @EnvironmentObject var store: StorageStore
    @Environment(\.dismiss) var dismiss

    @State var text: String = ""
    /// What the last import did, spelled out under the buttons.
    @State var message: String?
    @State var showClearDialog = false
    @State var showFileImporter = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    explainCard
                    editorCard
                    actionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Import app list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.blue)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                loadFile(result)
            }
            .confirmationDialog(
                "Clear the imported list?",
                isPresented: $showClearDialog,
                titleVisibility: .visible
            ) {
                Button("Clear \(store.importedApps.count) rows", role: .destructive) {
                    store.clearImportedApps()
                    message = "The imported list is empty again. Nothing on your iPhone was touched."
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Only the rows you imported are removed. Nothing is deleted from your iPhone.")
            }
        }
    }

    // MARK: - Actions

    private func importTapped() {
        let result = store.importApps(from: text)
        guard !result.apps.isEmpty else {
            message = "No app could be read from that text. Paste the output of ideviceinstaller -l -o list_all, a CSV, or the rows of Settings > General > iPhone Storage."
            return
        }

        text = ""
        var summary = "Imported \(result.apps.count) apps. The list now has \(store.importedApps.count) rows."
        if result.skipped > 0 {
            summary += " \(result.skipped) other lines were not app rows and were skipped."
        }
        message = summary
    }

    private func loadFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                message = "That file could not be read."
                return
            }
            guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1251)
                ?? String(data: data, encoding: .isoLatin1) else {
                message = "That file is not text."
                return
            }

            text = content
            message = "Loaded \(url.lastPathComponent). Tap Import to add its rows."
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

/// The cards of the import sheet.
extension ImportAppsView {
    /// Why an import is needed at all, and the three sources that actually work.
    var explainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why import a list?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("iOS 26 does not let a normally signed app — Feather, a certificate, the App Store — read the installed-app database, so the app cannot ask the iPhone for the list itself. A list made on a computer sees every app, so it is the only way to show all of them here. Nothing on the device is modified.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Separator(leading: 0)

            step(1, "Connect the iPhone to a computer, trust it, then run:", "ideviceinstaller -l -o list_all")
            step(2, "Or let the script of this repo collect it:", "powershell -File tools\\get-app-list.ps1")
            step(3, "Or type in the rows of Settings › General › iPhone Storage:", "Telegram\n2.14 GB\nInstagram\n412 MB")
        }
        .cardStyle(padding: 16)
    }

    func step(_ number: Int, _ title: String, _ code: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.accent))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    /// The text box, filled by a paste or by the file picker.
    var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The list")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(height: 190)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.cardElevated)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("com.burbn.instagram - Instagram (312.1.0)\nTelegram, 2.14 GB")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.tertiaryLabel)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Choose file…", systemImage: "doc.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
                .buttonStyle(PressableCardStyle())

                Spacer(minLength: 8)

                if !trimmedText.isEmpty {
                    Button {
                        text = ""
                        hideKeyboard()
                    } label: {
                        Text("Clear text")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
        .cardStyle(padding: 16)
    }

    /// The import button, the result of the last import and the way back out of an import.
    var actionsCard: some View {
        VStack(spacing: 12) {
            ActionButton(title: "Import", kind: .primary) {
                hideKeyboard()
                importTapped()
            }
            .opacity(trimmedText.isEmpty ? 0.45 : 1)
            .disabled(trimmedText.isEmpty)

            if let message = message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.importedApps.isEmpty {
                Separator(leading: 0)

                Text("\(store.importedApps.count) rows are imported right now, and they are what the Storage screen lists. Sizes show only where the text had them; nothing is estimated.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                ActionButton(title: "Clear imported list", kind: .destructive) {
                    showClearDialog = true
                }
            }
        }
        .cardStyle(padding: 16)
    }
}

