import Darwin
import Foundation
import ObjectiveC
import UIKit

/// Reads the apps that are really installed on this iPhone, together with their icons.
///
/// Both halves come from private iOS APIs. No App Store build may use them, but a sideloaded
/// build runs them happily:
///
/// * `+[LSApplicationWorkspace defaultWorkspace]` → `-allInstalledApplications` returns one
///   `LSApplicationProxy` per installed app (bundle id, name, short version, vendor).
/// * the proxy itself hands out its icon through `-iconDataForVariant:`; when that is missing,
///   `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]` is the second source.
///
/// Nothing is linked at compile time: every class and selector is resolved through the
/// Objective-C runtime and every call is guarded. An iOS release that renames one of them
/// only makes `isAvailable` (or `iconsAvailable`) return `false`, and the app keeps the demo
/// list or the gradient placeholder instead of crashing.
///
/// The UIImage lookup has one trap: it answers *every* bundle id, and for one that is not
/// installed it returns the grey "missing app" tile instead of nil. That tile used to win over
/// the App Store artwork, which is why the whole list showed grey squares. Two guards now stand
/// in the way: only bundles seen in the installed list are asked at all, and an image identical
/// to the placeholder is rejected.
enum InstalledAppsProvider {
    /// One installed app, reduced to the fields the UI needs.
    struct InstalledApp {
        let bundleID: String
        let name: String
        let version: String
        let developer: String
    }

    // MARK: - Availability

    /// `true` when this iOS build still exposes the installed-apps list.
    static var isAvailable: Bool {
        workspaceClass != nil && workspaceFactory != nil && !listSelectors.isEmpty
    }

    /// `true` when the private icon lookup is there as well. Without it the list still works,
    /// the tiles just fall back to the App Store artwork or to the placeholder.
    static var iconsAvailable: Bool {
        iconFunction != nil
    }

    /// Explanation for the Settings screen when `isAvailable` is `false`.
    static var unavailableReason: String? {
        if workspaceClass == nil || workspaceFactory == nil {
            return "This iOS version no longer exposes LSApplicationWorkspace."
        }
        if listSelectors.isEmpty {
            return "LSApplicationWorkspace no longer lists the installed apps."
        }
        return nil
    }

    // MARK: - Registry

    /// Proxies seen during the last scan, keyed by bundle id. The icon lookups go through them,
    /// and `isInstalled(_:)` uses the same table to tell a real app from an unknown bundle id —
    /// asking the private API about a bundle that is not on the device is what produced the grey
    /// placeholder tiles.
    private static let registryLock = NSLock()
    private static var registry: [String: NSObjectProtocol] = [:]

    /// `true` when the last scan found this bundle id on the device.
    static func isInstalled(_ bundleID: String) -> Bool {
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry[bundleID] != nil
    }

    /// Every bundle id the last scan returned. Empty until `loadApps()` has run.
    static var knownBundleIDs: Set<String> {
        registryLock.lock()
        defer { registryLock.unlock() }
        return Set(registry.keys)
    }

    private static func remember(_ bundleID: String, _ proxy: NSObjectProtocol) {
        registryLock.lock()
        registry[bundleID] = proxy
        registryLock.unlock()
    }

    private static func proxy(for bundleID: String) -> NSObjectProtocol? {
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry[bundleID]
    }

    // MARK: - The list

    /// Every app iOS knows about, sorted by name. Empty when the private API is gone.
    static func loadApps() -> [InstalledApp] {
        guard let workspace = defaultWorkspace() else { return [] }

        var raw: [AnyObject] = []
        for selector in listSelectors {
            raw.append(contentsOf: array(from: performObject(workspace, selector)))
        }
        guard !raw.isEmpty else { return [] }

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for element in raw {
            guard let proxy = element as? NSObjectProtocol else { continue }
            guard let bundleID = string(proxy, "bundleIdentifier"), !bundleID.isEmpty else { continue }
            guard seen.insert(bundleID).inserted else { continue }

            // `Hidden` stands for daemons and helpers without a Home Screen icon. Apple's hidden
            // entries are always system services, but sideloaded apps (TrollStore, permasigned
            // builds) report `Hidden` as well on some iOS versions, so only Apple's are dropped.
            if string(proxy, "applicationType") == "Hidden", bundleID.hasPrefix("com.apple.") {
                continue
            }

            remember(bundleID, proxy)

            let name = string(proxy, "localizedName")
                ?? string(proxy, "itemName")
                ?? string(proxy, "displayName")
                ?? bundleID
            let version = string(proxy, "shortVersionString") ?? "—"
            let developer = string(proxy, "vendorName") ?? "Installed on this device"

            apps.append(
                InstalledApp(
                    bundleID: bundleID,
                    name: name,
                    version: version,
                    developer: developer
                )
            )
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Icons

    /// The real Home Screen icon of `bundleID`, or `nil` when iOS refuses or the bundle is not
    /// on this device. `nil` is a normal answer: the caller then downloads the App Store artwork.
    static func icon(bundleID: String, scale: CGFloat) -> UIImage? {
        if let proxy = proxy(for: bundleID), let image = icon(from: proxy) {
            return image
        }

        // Never ask about a bundle the device does not have: the answer would be the grey
        // "missing app" tile, and it would hide the artwork the caller can download instead.
        // Apple's own apps are always there even before the scan has run (demo mode), and they
        // all sit under `com.apple.*`, so those are always fair game.
        guard isInstalled(bundleID) || bundleID.hasPrefix("com.apple.") else { return nil }
        guard let image = rawIcon(bundleID: bundleID, scale: scale) else { return nil }
        return isPlaceholder(image, scale: scale) ? nil : image
    }

    /// `-[LSApplicationProxy iconDataForVariant:]` — the exact icon iOS draws on the Home Screen.
    private static func icon(from proxy: NSObjectProtocol) -> UIImage? {
        let selector = NSSelectorFromString(iconDataSelectorName)
        guard proxy.responds(to: selector) else { return nil }

        for variant in ["@3x", "@2x"] {
            guard
                let data = proxy.perform(selector, with: variant as NSString)?
                    .takeUnretainedValue() as? Data,
                let image = UIImage(data: data)
            else { continue }

            return image
        }
        return nil
    }

    /// `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]` — the fallback when the
    /// proxy does not answer `iconDataForVariant:`.
    private static func rawIcon(bundleID: String, scale: CGFloat) -> UIImage? {
        guard
            let function = iconFunction,
            let imageClass = NSClassFromString("UIImage")
        else { return nil }

        return function(
            imageClass,
            NSSelectorFromString(iconSelectorName),
            bundleID as NSString,
            0,
            scale
        )?.takeUnretainedValue()
    }

    /// The grey tile the private lookup returns for anything it cannot resolve. It is captured
    /// once per scale by asking about a bundle id that cannot exist, and every later image is
    /// compared against it.
    private static let placeholderCacheLock = NSLock()
    private static var placeholderCache: [CGFloat: Data?] = [:]

    private static func placeholderSignature(scale: CGFloat) -> Data? {
        placeholderCacheLock.lock()
        if placeholderCache.keys.contains(scale) {
            let cached = placeholderCache[scale] ?? nil
            placeholderCacheLock.unlock()
            return cached
        }
        placeholderCacheLock.unlock()

        let signature = rawIcon(bundleID: "com.storageinspector.missing", scale: scale)?.pngData()

        placeholderCacheLock.lock()
        placeholderCache[scale] = signature
        placeholderCacheLock.unlock()
        return signature
    }

    private static func isPlaceholder(_ image: UIImage, scale: CGFloat) -> Bool {
        guard
            let signature = placeholderSignature(scale: scale),
            let data = image.pngData()
        else { return false }

        return data == signature
    }

    // MARK: - Runtime plumbing

    private typealias WorkspaceFactory = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
    private typealias IconFunction = @convention(c)
        (AnyClass, Selector, NSString, Int32, CGFloat) -> Unmanaged<UIImage>?

    private static let iconSelectorName = "_applicationIconImageForBundleIdentifier:format:scale:"
    private static let iconDataSelectorName = "iconDataForVariant:"

    private static let workspaceClass: AnyClass? = {
        openCandidateFrameworks()
        return NSClassFromString("LSApplicationWorkspace")
    }()

    /// `NSClassFromString` and `class_getClassMethod` only see what is already mapped into the
    /// process. The LibraryServices classes live in `MobileCoreServices` and the icon category in
    /// `MobileIcons`; neither is guaranteed to be loaded in a third party app, so the candidates
    /// are opened first. A path that does not exist is simply skipped.
    private static func openCandidateFrameworks() {
        let paths = [
            "/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",
            "/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices",
            "/System/Library/PrivateFrameworks/MobileIcons.framework/MobileIcons",
            "/System/Library/PrivateFrameworks/CoreServicesInternal.framework/CoreServicesInternal"
        ]

        for path in paths {
            _ = dlopen(path, RTLD_LAZY)
        }
    }

    private static let workspaceFactory: WorkspaceFactory? = {
        guard
            let cls = workspaceClass,
            let method = class_getClassMethod(cls, NSSelectorFromString("defaultWorkspace"))
        else { return nil }

        return unsafeBitCast(method_getImplementation(method), to: WorkspaceFactory.self)
    }()

    /// Every list selector this iOS build still answers. They are merged, because on some
    /// versions `allInstalledApplications` leaves out apps that `allApplications` still returns.
    private static let listSelectors: [Selector] = {
        guard let cls = workspaceClass else { return [] }

        var found: [Selector] = []
        for name in ["allInstalledApplications", "installedApplications", "allApplications"] {
            let selector = NSSelectorFromString(name)
            if class_getInstanceMethod(cls, selector) != nil {
                found.append(selector)
            }
        }
        return found
    }()

    private static let iconFunction: IconFunction? = {
        openCandidateFrameworks()

        guard
            let imageClass = NSClassFromString("UIImage"),
            let method = class_getClassMethod(imageClass, NSSelectorFromString(iconSelectorName))
        else { return nil }

        return unsafeBitCast(method_getImplementation(method), to: IconFunction.self)
    }()

    private static func defaultWorkspace() -> NSObjectProtocol? {
        guard let cls = workspaceClass, let factory = workspaceFactory else { return nil }

        let selector = NSSelectorFromString("defaultWorkspace")
        return factory(cls, selector)?.takeUnretainedValue() as? NSObjectProtocol
    }

    private static func performObject(_ object: NSObjectProtocol, _ selector: Selector?) -> AnyObject? {
        guard let selector = selector, object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }

    /// The list selectors answer with an `NSArray` on most versions, but `allApplications` has
    /// shipped an `NSSet` on some of them. `NSSet` does not cast to `[AnyObject]`, so a plain
    /// `as?` used to drop the whole answer — that is one of the ways apps went missing from the
    /// list.
    private static func array(from value: AnyObject?) -> [AnyObject] {
        if let array = value as? [AnyObject] {
            return array
        }
        if let set = value as? NSSet {
            return set.allObjects.compactMap { $0 as AnyObject }
        }
        return []
    }

    private static func string(_ object: NSObjectProtocol, _ name: String) -> String? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? String
    }
}
