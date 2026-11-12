import Foundation

/// Everything here touches the app's own sandbox only: bundle size, container size,
/// and the file browser behind the "View Files" button.
enum SandboxFiles {
    private static let fileManager = FileManager.default

    private static var homeURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var documentsURL: URL {
        directory(.documentDirectory)
    }

    static var roots: [SandboxRoot] {
        [
            SandboxRoot(id: "documents", title: "Documents", symbol: "doc.fill", url: documentsURL),
            SandboxRoot(id: "library", title: "Library", symbol: "books.vertical.fill", url: directory(.libraryDirectory)),
            SandboxRoot(id: "caches", title: "Caches", symbol: "arrow.triangle.2.circlepath", url: directory(.cachesDirectory))
        ]
    }

    static func directory(_ searchPath: FileManager.SearchPathDirectory) -> URL {
        if let url = fileManager.urls(for: searchPath, in: .userDomainMask).first {
            return url
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    // MARK: - Sizes

    /// Size of the `.app` bundle itself — the "App Size" row of the detail screen.
    static func appBundleSize() -> Int64 {
        size(of: Bundle.main.bundleURL)
    }

    /// Everything in the data container except the bundle — "Documents & Data".
    static func dataContainerSize() -> Int64 {
        let bundlePath = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard let entries = try? fileManager.contentsOfDirectory(at: homeURL, includingPropertiesForKeys: nil) else {
            return 0
        }

        var total: Int64 = 0
        for entry in entries {
            if entry.resolvingSymlinksInPath().standardizedFileURL.path == bundlePath { continue }
            total += size(of: entry)
        }
        return total
    }

    /// Recursive allocated size of a file or a whole folder.
    static func size(of url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue { return fileSize(url) }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: nil
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
    }
}

// MARK: - Browsing

extension SandboxFiles {
    /// Contents of a folder, folders first, then alphabetically.
    static func entries(in url: URL) -> [SandboxEntry] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return [] }

        let items = contents.map { item -> SandboxEntry in
            let values = try? item.resourceValues(forKeys: Set(keys))
            let isDirectory = values?.isDirectory ?? false
            let itemSize: Int64
            if isDirectory {
                itemSize = size(of: item)
            } else {
                itemSize = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            }
            return SandboxEntry(
                url: item,
                name: item.lastPathComponent,
                isDirectory: isDirectory,
                size: itemSize,
                modified: values?.contentModificationDate
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Fills Documents with a few example files so the browser is not empty on first run.
    static func createSampleFiles() throws {
        let documents = documentsURL
        let screenshots = documents.appendingPathComponent("Screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true, attributes: nil)

        let samples: [(String, Int)] = [
            ("IMG_0042.png", 1_240_000),
            ("IMG_0043.png", 2_980_000),
            ("IMG_0044.png", 860_000)
        ]
        for (name, bytes) in samples {
            let url = screenshots.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data(repeating: 0x41, count: bytes).write(to: url)
            }
        }

        let note = documents.appendingPathComponent("readme.txt")
        if !FileManager.default.fileExists(atPath: note.path) {
            let text = "Sample file created by Storage Inspector so the file browser has something to show.\n"
            try text.data(using: .utf8)?.write(to: note)
        }

        let cache = documents.appendingPathComponent("cache.bin")
        if !FileManager.default.fileExists(atPath: cache.path) {
            try Data(repeating: 0x2E, count: 5_400_000).write(to: cache)
        }
    }

    /// Shortened path for the UI: the container prefix becomes "~/".
    static func displayPath(for url: URL) -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(home) else { return path }
        return "~" + String(path.dropFirst(home.count))
    }
}
