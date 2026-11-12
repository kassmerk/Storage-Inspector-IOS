import SwiftUI

/// Row rendering and actions of `FileBrowserView`.
extension FileBrowserView {
    func row(for entry: SandboxEntry, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isDirectory ? "folder.fill" : fileSymbol(for: entry.name))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(entry.isDirectory ? Theme.accent : Theme.secondaryLabel)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(Formatters.date(entry.modified))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryLabel)
            }

            Spacer(minLength: 8)

            Text(Formatters.bytes(entry.size, unit: unit))
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
                .monospacedDigit()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    var footnote: some View {
        Text("These files live in this app's own container. Another app's container cannot be read from here.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryLabel)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    func reload() {
        entries = SandboxFiles.entries(in: url)
        totalSize = SandboxFiles.size(of: url)
    }

    func createSamples() {
        do {
            try SandboxFiles.createSampleFiles()
            errorText = nil
            reload()
        } catch {
            errorText = "Could not create files: \(error.localizedDescription)"
        }
    }

    func delete(_ entry: SandboxEntry) {
        do {
            try SandboxFiles.delete(entry.url)
            errorText = nil
            reload()
        } catch {
            errorText = "Could not delete: \(error.localizedDescription)"
        }
        pendingDelete = nil
    }

    func fileSymbol(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif":
            return "photo"
        case "txt", "md", "json":
            return "doc.text"
        case "zip", "7z", "rar":
            return "archivebox"
        default:
            return "doc"
        }
    }
}
