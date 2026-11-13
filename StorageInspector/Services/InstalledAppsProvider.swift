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
        /// Size of the app bundle, when this iOS build reports it (`staticDiskUsage`).
        let appSize: Int64?
        /// Size of Documents & Data, when this iOS build reports it (`dynamicDiskUsage`).
        let dataSize: Int64?
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

    // MARK: - Diagnostics

    /// One row of the report the Settings screen prints.
    struct Diagnostic {
        let title: String
        let value: String
    }

    /// What the private API actually answers on this device, in the order that separates a renamed
    /// API from a sandbox that is not allowed to see other apps:
    ///
    /// * the class and the factory — `not found` means this iOS build renamed the whole thing;
    /// * every list selector with its own count — a class that answers while all four counts are `0`
    ///   is the signature of a normally signed (Feather / certificate) install: iOS hides the
    ///   LaunchServices database from it, and TrollStore's `platform-application` entitlement is
    ///   what lifts the restriction;
    /// * the `applicationType` of everything that came back, so a filter can never be blamed for a
    ///   list the system never sent;
    /// * every bundle folder with the number of containers and `.app` bundles in it;
    /// * the rows the full scan ends up with, which is what the Storage screen shows.
    ///
    /// The report runs the real scan at the end, so it costs what the list costs.
    static func diagnostics(includeHidden: Bool) -> [Diagnostic] {
        var rows: [Diagnostic] = []

        let device = UIDevice.current
        rows.append(Diagnostic(title: "iOS", value: device.systemVersion + " · " + device.model))
        rows.append(Diagnostic(
            title: "LSApplicationWorkspace",
            value: workspaceClass == nil ? "not found" : "found"
        ))
        rows.append(Diagnostic(
            title: "defaultWorkspace",
            value: workspaceFactory == nil ? "missing" : "answered"
        ))
        rows.append(Diagnostic(
            title: "Icon lookup",
            value: iconFunction == nil ? "missing" : "answered"
        ))

        let workspace = defaultWorkspace()
        if workspace == nil {
            rows.append(Diagnostic(title: "workspace", value: "nil"))
        }

        var types: [String: Int] = [:]

        for name in listSelectorNames {
            let selector = NSSelectorFromString(name)
            guard let workspace = workspace, workspace.responds(to: selector) else {
                rows.append(Diagnostic(title: name, value: "no such selector"))
                continue
            }

            let elements = array(from: performObject(workspace, selector))
            rows.append(Diagnostic(title: name, value: "\(elements.count) entries"))

            for element in elements {
                guard let proxy = element as? NSObjectProtocol else { continue }
                let type = string(proxy, "applicationType") ?? "unknown"
                types[type, default: 0] += 1
            }
        }

        if !types.isEmpty {
            let histogram = types
                .sorted { $0.key < $1.key }
                .map { "\($0.key) \($0.value)" }
                .joined(separator: " · ")
            rows.append(Diagnostic(title: "applicationType", value: histogram))
        }

        let manager = FileManager.default
        for root in bundleRoots {
            guard let containers = try? manager.contentsOfDirectory(atPath: root) else {
                rows.append(Diagnostic(title: root, value: "not readable"))
                continue
            }
            let bundles = bundleApps(in: root).count
            rows.append(Diagnostic(
                title: root,
                value: "\(containers.count) containers · \(bundles) bundles"
            ))
        }

        rows.append(Diagnostic(
            title: "Rows returned",
            value: "\(loadApps(includeHidden: includeHidden).count)"
        ))
        return rows
    }

    // MARK: - Registry

    /// Proxies seen during the last scan, keyed by bundle id. The icon lookups go through them,
    /// and `isInstalled(_:)` uses the same table to tell a real app from an unknown bundle id —
    /// asking the private API about a bundle that is not on the device is what produced the grey
    /// placeholder tiles.
    private static let registryLock = NSLock()
    private static var registry: [String: NSObjectProtocol] = [:]
    /// Bundle ids found by walking the bundle folders instead of the LaunchServices database.
    /// Those apps have no proxy, but they are on the device all the same.
    private static var folderBundleIDs: Set<String> = []
    /// The `.app` folder of every app the last scan saw, keyed by bundle id.
    ///
    /// It is what makes the icon of a sideloaded app possible: `Null's Clash`, a TrollStore build,
    /// any unsigned `.ipa` never reached the App Store, so neither the proxy nor the artwork lookup
    /// has a picture for it — the PNG inside its own bundle is the only one, and it is exactly the
    /// file the Home Screen draws.
    private static var bundleURLs: [String: URL] = [:]

    /// `true` when LaunchServices still answers a question about one bundle id.
    ///
    /// `-applicationProxyForIdentifier:` asks about a single bundle instead of listing everything,
    /// and the sandbox sometimes keeps that channel open when the list itself comes back empty. It
    /// needs no `LSApplicationQueriesSchemes` declaration, which makes it the cheaper of the two
    /// channels `AppSchemeProbe` tries.
    static func isBundlePresent(_ bundleID: String) -> Bool {
        let known = knownBundleIDs
        if known.contains(bundleID) { return true }

        let name = "applicationProxyForIdentifier:"
        let selector = NSSelectorFromString(name)
        guard
            let workspace = defaultWorkspace(),
            workspace.responds(to: selector)
        else { return false }

        // A non-nil answer means LaunchServices knows this bundle; nil means it does not. The proxy
        // itself is not kept: the whole point of the call is the yes/no, and a stale proxy would be
        // rejected by the private getters anyway.
        let proxy = workspace.perform(selector, with: bundleID as NSString)?.takeUnretainedValue()
        return proxy != nil
    }

    /// `true` when the last scan found this bundle id on the device.
    static func isInstalled(_ bundleID: String) -> Bool {
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry[bundleID] != nil || folderBundleIDs.contains(bundleID)
    }

    /// Every bundle id the last scan returned. Empty until `loadApps()` has run.
    static var knownBundleIDs: Set<String> {
        registryLock.lock()
        defer { registryLock.unlock() }
        return Set(registry.keys).union(folderBundleIDs)
    }

    private static func remember(_ bundleID: String, _ proxy: NSObjectProtocol) {
        // `bundleURL` answers on every version that has the proxy at all, and it is the folder the
        // icon and the byte count of a sideloaded app are read from when the getters stay silent.
        let folder = performObject(proxy, NSSelectorFromString("bundleURL")) as? URL

        registryLock.lock()
        registry[bundleID] = proxy
        if let folder = folder {
            bundleURLs[bundleID] = folder
        }
        registryLock.unlock()
    }

    /// Remembers a bundle that came from the folder scan, so its icon lookup is allowed too.
    private static func remember(_ bundleID: String, folder: URL? = nil) {
        registryLock.lock()
        folderBundleIDs.insert(bundleID)
        if let folder = folder {
            bundleURLs[bundleID] = folder
        }
        registryLock.unlock()
    }

    /// The `.app` folder of a bundle the last scan saw, when one of the sources handed it over.
    private static func bundleURL(for bundleID: String) -> URL? {
        registryLock.lock()
        defer { registryLock.unlock() }
        return bundleURLs[bundleID]
    }

    private static func proxy(for bundleID: String) -> NSObjectProtocol? {
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry[bundleID]
    }

    // MARK: - The list

    /// Every app iOS knows about, sorted by name. Empty when both the private API and the folder
    /// scan come back with nothing.
    ///
    /// Two sources are merged, because each one alone misses something:
    ///
    /// * the LaunchServices database (`allInstalledApplications` and friends) — the normal path;
    /// * the bundle folders on disk — only readable on TrollStore / jailbroken installs, but it
    ///   picks up the apps the database hides (`applicationType == Hidden`) and measures a size
    ///   for the rows where iOS refuses to answer `staticDiskUsage`.
    ///
    /// `includeHidden` also keeps Apple's hidden daemons and helpers. They have no Home Screen
    /// icon, which is why "iPhone Storage" hides them, but a sideloaded build may show everything.
    static func loadApps(includeHidden: Bool = false) -> [InstalledApp] {
        var onDisk = scanBundleFolders()

        var raw: [AnyObject] = []
        if let workspace = defaultWorkspace() {
            for selector in listSelectors {
                raw.append(contentsOf: array(from: performObject(workspace, selector)))
            }
        }

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for element in raw {
            guard let proxy = element as? NSObjectProtocol else { continue }
            guard let bundleID = string(proxy, "bundleIdentifier"), !bundleID.isEmpty else { continue }
            guard seen.insert(bundleID).inserted else { continue }

            // `Hidden` stands for daemons and helpers without a Home Screen icon. Apple's hidden
            // entries are always system services, but sideloaded apps (TrollStore, permasigned
            // builds) report `Hidden` as well on some iOS versions, so only Apple's are dropped.
            if !includeHidden,
               string(proxy, "applicationType") == "Hidden",
               bundleID.hasPrefix("com.apple.") {
                continue
            }

            remember(bundleID, proxy)

            let name = string(proxy, "localizedName")
                ?? string(proxy, "itemName")
                ?? string(proxy, "displayName")
                ?? bundleID
            let version = string(proxy, "shortVersionString") ?? "—"
            let developer = string(proxy, "vendorName") ?? "Installed on this device"

            let usage = diskUsage(of: proxy)

            apps.append(
                InstalledApp(
                    bundleID: bundleID,
                    name: name,
                    version: version,
                    developer: developer,
                    appSize: usage.app ?? onDisk.size(of: bundleID),
                    dataSize: usage.data
                )
            )
        }

        // The apps the database left out. Without this pass a hidden TrollStore install had no row
        // at all, which is how an app could sit on the device and be missing from the list.
        // The dictionary is copied out first: the measuring call below mutates the scan.
        let folderApps = onDisk.apps
        for (bundleID, app) in folderApps where !seen.contains(bundleID) {
            seen.insert(bundleID)
            remember(bundleID, folder: onDisk.urls[bundleID])
            apps.append(
                InstalledApp(
                    bundleID: app.bundleID,
                    name: app.name,
                    version: app.version,
                    developer: app.developer,
                    // The folder is right there, so the size is measured even on the rows no proxy
                    // ever answered for.
                    appSize: onDisk.size(of: bundleID),
                    dataSize: nil
                )
            )
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Folder scan

    /// What the folder pass found: metadata for the apps the database does not return, and the
    /// bundle URL of every app it saw, so a size can be measured where iOS hides it.
    private struct FolderScan {
        var apps: [String: InstalledApp] = [:]
        var urls: [String: URL] = [:]
        private var sizes: [String: Int64?] = [:]

        /// Recursive size of the bundle, measured at most once per bundle id.
        mutating func size(of bundleID: String) -> Int64? {
            guard let url = urls[bundleID] else { return nil }
            if let cached = sizes[bundleID] { return cached }

            let measured = SandboxFiles.size(of: url)
            let answer: Int64? = measured > 0 ? measured : nil
            sizes[bundleID] = answer
            return answer
        }
    }

    /// Walks the places where iOS keeps app bundles. A stock sandbox may not read any of them, so
    /// the answer is simply empty there; TrollStore and jailbroken devices do get the full list,
    /// including the apps LaunchServices refuses to hand out.
    /// Every place iOS keeps app bundles. The `/private/var` twin and the `/var/jb` prefixes are
    /// listed as well: a TrollStore install and a rootless jailbreak land in one of those, and the
    /// same app is reachable through two of them often enough to be worth the extra checks.
    private static let bundleRoots = [
        "/var/containers/Bundle/Application",
        "/private/var/containers/Bundle/Application",
        "/Applications",
        "/var/jb/var/containers/Bundle/Application",
        "/var/jb/Applications"
    ]

    private static func scanBundleFolders() -> FolderScan {
        var scan = FolderScan()
        for root in bundleRoots {
            for (bundleID, app, url) in bundleApps(in: root) where scan.urls[bundleID] == nil {
                scan.apps[bundleID] = app
                scan.urls[bundleID] = url
            }
        }
        return scan
    }

    /// `<root>/<container>/<Name>.app` — one level of containers, then the bundle itself.
    private static func bundleApps(in root: String) -> [(String, InstalledApp, URL)] {
        let manager = FileManager.default
        guard let containers = try? manager.contentsOfDirectory(atPath: root) else { return [] }

        var found: [(String, InstalledApp, URL)] = []
        for container in containers {
            let containerURL = URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent(container)

            guard let children = try? manager.contentsOfDirectory(
                at: containerURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children where child.pathExtension == "app" {
                if let app = app(fromBundleAt: child) {
                    found.append((app.bundleID, app, child))
                }
            }
        }
        return found
    }

    /// Reads `Info.plist` of a bundle folder and builds the row from it.
    private static func app(fromBundleAt url: URL) -> InstalledApp? {
        let infoURL = url.appendingPathComponent("Info.plist")
        guard
            let data = try? Data(contentsOf: infoURL),
            let plist = (try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )) as? [String: Any],
            let bundleID = plist["CFBundleIdentifier"] as? String,
            !bundleID.isEmpty
        else { return nil }

        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleID
        let version = (plist["CFBundleShortVersionString"] as? String) ?? "—"

        return InstalledApp(
            bundleID: bundleID,
            name: name,
            version: version,
            developer: "Installed on this device",
            appSize: nil,
            dataSize: nil
        )
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
        if isInstalled(bundleID) || bundleID.hasPrefix("com.apple."),
           let image = rawIcon(bundleID: bundleID, scale: scale),
           !isPlaceholder(image, scale: scale) {
            return image
        }

        // Last source: the picture shipped inside the bundle itself. A sideloaded app has no App
        // Store artwork, and iOS only draws an icon for a bundle it has indexed, so this PNG is the
        // only picture `Null's Clash`, Feather or any TrollStore build can get.
        return bundleIcon(bundleID: bundleID)
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

    /// The icon file that ships inside the bundle itself.
    ///
    /// `CFBundleIcons` names it, and when the plist is terse the biggest `AppIcon*.png` in the
    /// folder is taken instead. This is the only source left for an app that never went through the
    /// App Store: the proxy has no artwork for it, and the private UIImage lookup answers with the
    /// grey "missing app" tile. It needs the `.app` folder, so it works exactly when the folder scan
    /// works — TrollStore and jailbroken installs.
    private static func bundleIcon(bundleID: String) -> UIImage? {
        guard let bundle = bundleURL(for: bundleID) else { return nil }

        let manager = FileManager.default
        for name in iconFileNames(in: bundle) {
            let url = bundle.appendingPathComponent(name)
            guard manager.fileExists(atPath: url.path) else { continue }
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        guard let files = try? manager.contentsOfDirectory(
            at: bundle,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // `@3x` sorts above `@2x`, so the sharpest variant comes first without reading any
        // attributes: a directory listing per bundle is all this costs.
        let candidates = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .filter {
                let name = $0.lastPathComponent.lowercased()
                return name.hasPrefix("appicon") || name.hasPrefix("icon")
            }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for candidate in candidates {
            if let image = UIImage(contentsOfFile: candidate.path) {
                return image
            }
        }
        return nil
    }

    /// Icon file names declared by the bundle's `Info.plist`, sharpest first and with the `.png`
    /// suffix filled in. Both the modern `CFBundleIcons` dictionary and the older flat keys are
    /// read, because sideloaded bundles carry either one.
    private static func iconFileNames(in bundle: URL) -> [String] {
        let infoURL = bundle.appendingPathComponent("Info.plist")
        guard
            let data = try? Data(contentsOf: infoURL),
            let plist = (try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )) as? [String: Any]
        else { return [] }

        var declared: [String] = []

        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard let icons = plist[key] as? [String: Any] else { continue }
            guard let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else { continue }

            if let files = primary["CFBundleIconFiles"] as? [String] {
                declared.append(contentsOf: files)
            }
            if let name = primary["CFBundleIconName"] as? String {
                declared.append(name)
            }
        }

        if let files = plist["CFBundleIconFiles"] as? [String] {
            declared.append(contentsOf: files)
        }
        if let file = plist["CFBundleIconFile"] as? String {
            declared.append(file)
        }

        // The plist lists the small file first, so the array is walked backwards. Every name is
        // also tried with `.png`: the extension is optional in `CFBundleIconFile`.
        var names: [String] = []
        for name in declared.reversed() {
            names.append(name)
            if !name.contains(".") {
                names.append(name + ".png")
            }
        }
        return names
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

    /// Every list selector an iOS build has answered with. `visibleApplications` is asked too: on
    /// the versions where the other three come back empty for a normally signed app, it is the one
    /// that still answers, and a duplicate entry costs nothing because the loop dedupes by bundle id.
    private static let listSelectorNames = [
        "allInstalledApplications",
        "installedApplications",
        "allApplications",
        "visibleApplications"
    ]

    /// Every list selector this iOS build still answers. They are merged, because on some
    /// versions `allInstalledApplications` leaves out apps that `allApplications` still returns.
    private static let listSelectors: [Selector] = {
        guard let cls = workspaceClass else { return [] }

        var found: [Selector] = []
        for name in listSelectorNames {
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

    // MARK: - Disk usage

    /// The two halves of an app's footprint, when this iOS build still reports them.
    ///
    /// `LSApplicationProxy` carries `-staticDiskUsage` (the bundle, what iOS prints as "App Size")
    /// and `-dynamicDiskUsage` (Documents & Data). Both are private, some builds answer `0`, and a
    /// future release may drop them — then the answer is `nil` and the UI prints a dash instead of
    /// inventing a number. That is exactly the difference between this and the demo dataset: a
    /// number here was measured by iOS itself.
    ///
    /// When the getters are missing, the bundle folder and the data container are walked instead.
    /// A stock sandbox cannot read either, but TrollStore / jailbroken installs can, and then the
    /// sizes are measured byte by byte.
    static func diskUsage(of proxy: NSObjectProtocol) -> (app: Int64?, data: Int64?) {
        var app = byteCount(proxy, ["staticDiskUsage", "bundleDiskUsage", "installedSize"])
        var data = byteCount(proxy, ["dynamicDiskUsage", "dataDiskUsage", "documentsSize"])

        if app == nil { app = folderSize(proxy, ["bundleURL"]) }
        if data == nil { data = folderSize(proxy, ["dataContainerURL"]) }

        return (app, data)
    }

    /// Byte count from a private getter, `nil` when it is missing or answers 0.
    ///
    /// The getter may be declared either way: an object one (`NSNumber`) is safe through
    /// `perform`, a plain integer one is boxed by KVC. Anything else — a struct, a float, an
    /// unknown shape — is skipped, so a renamed getter can never hand back garbage.
    private static func byteCount(_ object: NSObjectProtocol, _ names: [String]) -> Int64? {
        guard let object = object as? NSObject else { return nil }

        for name in names {
            let selector = NSSelectorFromString(name)
            guard object.responds(to: selector) else { continue }
            guard
                let method = class_getInstanceMethod(type(of: object), selector),
                let types = method_getTypeEncoding(method)
            else { continue }

            let encoding = String(cString: types)

            if encoding.hasPrefix("@") {
                if let number = object.perform(selector)?.takeUnretainedValue() as? NSNumber,
                   number.int64Value > 0 {
                    return number.int64Value
                }
            } else if encoding.hasPrefix("Q") || encoding.hasPrefix("q")
                        || encoding.hasPrefix("I") || encoding.hasPrefix("i")
                        || encoding.hasPrefix("L") || encoding.hasPrefix("l") {
                if let number = object.value(forKey: name) as? NSNumber, number.int64Value > 0 {
                    return number.int64Value
                }
            }
        }
        return nil
    }

    /// Recursive size of a folder handed out through a private getter such as `bundleURL`.
    private static func folderSize(_ object: NSObjectProtocol, _ names: [String]) -> Int64? {
        guard let object = object as? NSObject else { return nil }

        for name in names {
            let selector = NSSelectorFromString(name)
            guard object.responds(to: selector) else { continue }

            if let url = object.perform(selector)?.takeUnretainedValue() as? URL {
                let size = SandboxFiles.size(of: url)
                if size > 0 { return size }
            }
        }
        return nil
    }

    private static func string(_ object: NSObjectProtocol, _ name: String) -> String? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? String
    }
}
