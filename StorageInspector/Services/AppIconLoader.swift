import Foundation
import SwiftUI
import UIKit

/// Resolves the picture inside an app tile, best source first:
///
/// 1. a PNG bundled in `Resources/AppIcons` (`icon-<bundle-id>.png` or `icon-<item id>.png`) —
///    wins everywhere, works offline, and is how hand-cut icons made from your own screenshots
///    get in (see `tools/make-app-icon.ps1`);
/// 2. the icon of the app really installed on this device (private API behind
///    `InstalledAppsProvider`), tried whenever iOS still answers that call;
/// 3. the official App Store artwork, downloaded from `itunes.apple.com/lookup?bundleId=…`;
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

    private let session: URLSession
    private let cacheDirectory: URL
    /// Read once on the main thread so the background work never touches `UIScreen`.
    private let scale: CGFloat
    /// Ids already handled in this session, so a scrolling list does not re-request them.
    private var requested: Set<String> = []

    init(session: URLSession = .shared) {
        self.session = session
        self.scale = UIScreen.main.scale

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        cacheDirectory = (caches ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("AppIcons", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    /// The picture for a row, or `nil` while it is missing (the tile keeps its placeholder).
    func image(for item: AppItem) -> UIImage? {
        images[item.id]
    }

    /// Loads whatever is still missing for `items`. Bundled and cached files appear at once,
    /// the rest is resolved one item at a time in the background.
    ///
    /// - Parameter deviceIcons: `true` while iOS still answers the private icon lookup. It is
    ///   tried first for every row and the App Store artwork is the fallback; `false` skips the
    ///   private call entirely.
    func load(_ items: [AppItem], deviceIcons: Bool) {
        let pending = items.filter { !requested.contains($0.id) }
        guard !pending.isEmpty else { return }
        pending.forEach { requested.insert($0.id) }

        var resolved: [String: UIImage] = [:]
        var toLoad: [AppItem] = []

        for item in pending {
            if let bundled = AppIconLoader.bundledIcon(for: item) {
                resolved[item.id] = bundled
            } else if let cached = readCache(for: item, deviceIcons: deviceIcons) {
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
            guard let self = self else { return }

            for item in toLoad {
                // The icon of the installed app first (no network at all), then the store.
                var image: UIImage?
                if deviceIcons {
                    image = self.deviceIcon(for: item)
                }
                if image == nil {
                    image = await self.storeArtwork(for: item)
                }
                guard let image = image else { continue }

                await MainActor.run { self.images[item.id] = image }
                self.writeCache(image, for: item, deviceIcons: deviceIcons)
            }

            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Sources

    /// The real Home Screen icon for the installed-apps list.
    private func deviceIcon(for item: AppItem) -> UIImage? {
        guard let bundleID = item.bundleID else { return nil }
        return InstalledAppsProvider.icon(bundleID: bundleID, scale: scale)
    }

    /// The official App Store artwork for the demo rows.
    private func storeArtwork(for item: AppItem) async -> UIImage? {
        guard
            let bundleID = item.bundleID,
            let lookupURL = AppIconLoader.lookupURL(bundleID: bundleID)
        else { return nil }

        do {
            let (lookupData, _) = try await session.data(from: lookupURL)
            let response = try JSONDecoder().decode(LookupResponse.self, from: lookupData)
            guard let artworkURL = AppIconLoader.largeArtworkURL(response.results.first) else {
                return nil
            }

            let (imageData, _) = try await session.data(from: artworkURL)
            return UIImage(data: imageData)
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

    private static func lookupURL(bundleID: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "us")
        ]
        return components?.url
    }

    /// The real `artworkUrl512` when the store publishes it, otherwise the `100x100bb` file
    /// re-pointed at `512x512bb` — the same artwork, sharp enough for a 62 pt tile at 3×.
    private static func largeArtworkURL(_ result: LookupResponse.Result?) -> URL? {
        guard let result = result else { return nil }
        if let big = result.artworkUrl512, let url = URL(string: big) {
            return url
        }
        guard let small = result.artworkUrl100 else { return nil }
        let large = small.replacingOccurrences(of: "100x100bb", with: "512x512bb")
        return URL(string: large)
    }

    // MARK: - Disk cache

    private static func cacheKey(for raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty ? "icon" : cleaned
    }

    private func cacheURL(for item: AppItem, deviceIcons: Bool) -> URL {
        let prefix = deviceIcons ? "device" : "store"
        let key = AppIconLoader.cacheKey(for: item.bundleID ?? item.id)
        return cacheDirectory.appendingPathComponent("\(prefix)-\(key).png")
    }

    private func readCache(for item: AppItem, deviceIcons: Bool) -> UIImage? {
        UIImage(contentsOfFile: cacheURL(for: item, deviceIcons: deviceIcons).path)
    }

    private func writeCache(_ image: UIImage, for item: AppItem, deviceIcons: Bool) {
        guard let data = image.pngData() else { return }
        try? data.write(to: cacheURL(for: item, deviceIcons: deviceIcons), options: .atomic)
    }

    // MARK: - Decoding

    private struct LookupResponse: Decodable {
        let results: [Result]

        struct Result: Decodable {
            let artworkUrl100: String?
            let artworkUrl512: String?
        }
    }
}
