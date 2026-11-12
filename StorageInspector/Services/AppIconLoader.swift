import Foundation
import SwiftUI
import UIKit

/// Resolves the picture inside an app tile, best source first:
///
/// 1. a PNG bundled in `Resources/AppIcons` (`icon-<bundle-id>.png` or `icon-<item id>.png`) —
///    wins everywhere, works offline, and is how hand-cut icons made from your own screenshots
///    get in (see `tools/make-app-icon.ps1`);
/// 2. the icon of the app really installed on this device (private API behind
///    `InstalledAppsProvider`), tried whenever iOS still answers that call *and* the bundle is
///    really on the device;
/// 3. the official App Store artwork, looked up by bundle id first and by app name second;
/// 4. nothing, and the tile keeps its gradient + SF Symbol placeholder.
///
/// The class stays off `@MainActor` on purpose, exactly like `AppIconManager`: it is created
/// inside a SwiftUI property initializer, and only the publishing hops onto the main actor.
/// `load(_:deviceIcons:)` is expected to be called from the main thread.
final class AppIconLoader: ObservableObject {
    /// Images keyed by `AppItem.id`.
    @Published private(set) var images: [String: UIImage] = [:]
    /// `true` while something is still loading in the background.
    @Published private(set) var isLoading = false

    /// How many icons are fetched at the same time. The list is walked in batches, so a hundred
    /// rows finish in about the time of a handful of lookups instead of a hundred of them.
    private static let batchSize = 6

    private let session: URLSession
    private let cacheDirectory: URL
    /// Storefront used for the artwork lookups. Asking the US store about an app that only exists
    /// in, say, the Russian one returns nothing, which used to leave a grey tile behind.
    private let storefront: String
    /// Read once on the main thread so the background work never touches `UIScreen`.
    private let scale: CGFloat
    /// Ids already handled in this session, so a scrolling list does not re-request them.
    private var requested: Set<String> = []

    init(session: URLSession = AppIconLoader.makeSession()) {
        self.session = session
        self.scale = UIScreen.main.scale
        self.storefront = Locale.current.region?.identifier ?? "US"

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        cacheDirectory = (caches ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("AppIcons", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Older builds kept one file per source ("device-…", "store-…"). The cache is one file per
        // app now, so the leftovers are dropped instead of taking room forever.
        removeLegacyCacheFiles()
    }

    /// `itunes.apple.com` occasionally stalls a request, and one stuck request used to hold the
    /// whole list back. A timeout plus a real user agent keeps the queue moving.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = [
            "User-Agent": "StorageInspector/1.0 (iPhone; iOS \(UIDevice.current.systemVersion))"
        ]
        return URLSession(configuration: configuration)
    }

    /// The picture for a row, or `nil` while it is missing (the tile keeps its placeholder).
    func image(for item: AppItem) -> UIImage? {
        images[item.id]
    }

    /// Forgets which rows were already handled, so the next `load(_:deviceIcons:)` retries the
    /// ones that are still empty. The installed-apps list arrives after the first pass, and only
    /// then can the real Home Screen icons be read for the demo rows as well.
    func forget() {
        requested.removeAll()
    }

    /// Loads whatever is still missing for `items`. Bundled and cached files appear at once, the
    /// rest is resolved in parallel batches in the background and published in one go, so the
    /// list is not rebuilt row by row while a finger is on the screen.
    ///
    /// - Parameter deviceIcons: `true` while iOS still answers the private icon lookup. It is
    ///   tried first for every row and the App Store artwork is the fallback; `false` skips the
    ///   private call entirely.
    func load(_ items: [AppItem], deviceIcons: Bool) {
        let pending = items.filter { !requested.contains($0.id) && images[$0.id] == nil }
        guard !pending.isEmpty else { return }
        pending.forEach { requested.insert($0.id) }

        var resolved: [String: UIImage] = [:]
        var toLoad: [AppItem] = []

        for item in pending {
            if let bundled = AppIconLoader.bundledIcon(for: item) {
                resolved[item.id] = bundled
            } else if let cached = readCache(for: item) {
                resolved[item.id] = cached
            } else if item.bundleID != nil {
                toLoad.append(item)
            }
        }

        if !resolved.isEmpty {
            images.merge(resolved) { _, new in new }
        }
        guard !toLoad.isEmpty else { return }

        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            await self.download(toLoad, deviceIcons: deviceIcons)
        }
    }

    private func download(_ items: [AppItem], deviceIcons: Bool) async {
        var loaded: [String: UIImage] = [:]
        var start = 0

        while start < items.count {
            let end = min(start + AppIconLoader.batchSize, items.count)
            let batch = Array(items[start..<end])

            let results = await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (offset, item) in batch.enumerated() {
                    group.addTask {
                        (offset, await self.resolve(item, deviceIcons: deviceIcons))
                    }
                }

                var found: [(Int, UIImage)] = []
                for await (offset, image) in group {
                    guard let image = image else { continue }
                    found.append((offset, image))
                }
                return found
            }

            for (offset, image) in results {
                let item = batch[offset]
                loaded[item.id] = image
                writeCache(image, for: item)
            }

            start = end
        }

        let images = loaded
        await MainActor.run {
            if !images.isEmpty {
                self.images.merge(images) { _, new in new }
            }
            self.isLoading = false
        }
    }

    private func resolve(_ item: AppItem, deviceIcons: Bool) async -> UIImage? {
        if deviceIcons, let device = deviceIcon(for: item) {
            return device
        }
        return await storeArtwork(for: item)
    }

    private func deviceIcon(for item: AppItem) -> UIImage? {
        guard let bundleID = item.bundleID else { return nil }
        return InstalledAppsProvider.icon(bundleID: bundleID, scale: scale)
    }

    /// The official artwork: `lookup?bundleId=…` first, then a search by name. A search hit is
    /// accepted only when the name matches, so a renamed or store-less app never wears a
    /// stranger's icon.
    private func storeArtwork(for item: AppItem) async -> UIImage? {
        if
            let bundleID = item.bundleID,
            let url = lookupURL(bundleID: bundleID),
            let image = await artwork(from: url, matching: nil)
        {
            return image
        }

        guard let endpoint = searchURL(term: item.name) else { return nil }
        return await artwork(from: endpoint, matching: item.name)
    }

    private func artwork(from url: URL, matching name: String?) async -> UIImage? {
        do {
            let (payload, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: payload)
            guard
                let result = AppIconLoader.bestResult(in: response.results, matching: name),
                let artworkURL = AppIconLoader.largeArtworkURL(result)
            else { return nil }

            let (data, _) = try await session.data(from: artworkURL)
            return UIImage(data: data)
        } catch {
            // Offline, throttled or the app is gone from this storefront: keep the placeholder.
            return nil
        }
    }

    /// Hand-cut icons shipped inside the app bundle, packaged by `tools/make-app-icon.ps1`.
    private static func bundledIcon(for item: AppItem) -> UIImage? {
        for name in bundledNames(for: item) {
            guard
                let url = Bundle.main.url(forResource: "AppIcons/\(name)", withExtension: "png")
            else { continue }

            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }

    private static func bundledNames(for item: AppItem) -> [String] {
        var names: [String] = []
        if let bundleID = item.bundleID {
            names.append("icon-\(cacheKey(for: bundleID))")
        }

        let idName = "icon-\(cacheKey(for: item.id))"
        if !names.contains(idName) {
            names.append(idName)
        }
        return names
    }

    // MARK: - Network helpers

    private func lookupURL(bundleID: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: storefront)
        ]
        return components?.url
    }

    /// Finds the artwork of apps whose bundle id the store does not know (renamed builds, apps
    /// that were pulled from sale, region-locked releases).
    private func searchURL(term: String) -> URL? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "country", value: storefront)
        ]
        return components?.url
    }

    /// Without a name to match, the first hit is the answer; with one, only a result whose title
    /// really is that app gets through.
    private static func bestResult(
        in results: [LookupResponse.Result],
        matching name: String?
    ) -> LookupResponse.Result? {
        guard let name = name else { return results.first }

        let wanted = normalized(name)
        guard wanted.count >= 3 else { return results.first }

        return results.first { result in
            guard let title = result.trackName else { return false }
            let candidate = normalized(title)
            guard candidate.count >= 3 else { return false }
            // Exact match only. The old prefix rule gave "Photos" the icon of an unrelated app
            // called "Photos+" — a wrong picture is worse than the gradient placeholder.
            return candidate == wanted
        }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// The real `artworkUrl512` when the store publishes it, otherwise the smaller file
    /// re-pointed at `512x512bb` — the same artwork, sharp enough for a 62 pt tile at 3×.
    private static func largeArtworkURL(_ result: LookupResponse.Result?) -> URL? {
        guard let result = result else { return nil }
        if let big = result.artworkUrl512, let url = URL(string: big) {
            return url
        }

        for candidate in [result.artworkUrl100, result.artworkUrl60] {
            guard let candidate = candidate else { continue }
            for size in ["100x100bb", "60x60bb"] {
                guard candidate.contains(size) else { continue }
                return URL(string: candidate.replacingOccurrences(of: size, with: "512x512bb"))
            }
            if let url = URL(string: candidate) {
                return url
            }
        }
        return nil
    }

    // MARK: - Disk cache

    private static func cacheKey(for raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty ? "icon" : cleaned
    }

    /// One file per app, no matter where the image came from, so a row keeps its picture across
    /// launches and a cold start draws the list without waiting for the network.
    private func cacheURL(for item: AppItem) -> URL {
        let key = AppIconLoader.cacheKey(for: item.bundleID ?? item.id)
        return cacheDirectory.appendingPathComponent("icon-\(key).png")
    }

    private func readCache(for item: AppItem) -> UIImage? {
        UIImage(contentsOfFile: cacheURL(for: item).path)
    }

    private func writeCache(_ image: UIImage, for item: AppItem) {
        guard let data = image.pngData() else { return }
        try? data.write(to: cacheURL(for: item), options: .atomic)
    }

    private func removeLegacyCacheFiles() {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix("device-") || name.hasPrefix("store-") else { continue }
            try? manager.removeItem(at: entry)
        }
    }

    // MARK: - Decoding

    private struct LookupResponse: Decodable {
        let results: [Result]

        struct Result: Decodable {
            let trackName: String?
            let artworkUrl60: String?
            let artworkUrl100: String?
            let artworkUrl512: String?
        }
    }
}



