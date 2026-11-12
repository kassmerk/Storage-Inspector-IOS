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
/// * `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]` returns the exact
///   Home Screen icon of that app — nothing to download, nothing to guess.
///
/// Nothing is linked at compile time: every class and selector is resolved through the
/// Objective-C runtime and every call is guarded. An iOS release that renames one of them
/// only makes `isAvailable` (or `iconsAvailable`) return `false`, and the app keeps the demo
/// list or the gradient placeholder instead of crashing.
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
        workspaceClass != nil && listSelector != nil && workspaceFactory != nil
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
        if listSelector == nil {
            return "LSApplicationWorkspace no longer lists the installed apps."
        }
        return nil
    }

    // MARK: - The list

    /// Every app iOS knows about, sorted by name. Empty when the private API is gone.
    static func loadApps() -> [InstalledApp] {
        guard
            let workspace = defaultWorkspace(),
            let raw = performObject(workspace, listSelector) as? [AnyObject]
        else { return [] }

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for element in raw {
            guard let proxy = element as? NSObjectProtocol else { continue }
            guard let bundleID = string(proxy, "bundleIdentifier"), !bundleID.isEmpty else { continue }
            guard seen.insert(bundleID).inserted else { continue }
            // `Hidden` entries are daemons and helpers without a Home Screen icon.
            if string(proxy, "applicationType") == "Hidden" { continue }

            let name = string(proxy, "localizedName")
                ?? string(proxy, "itemName")
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

    /// The real Home Screen icon of `bundleID`, or `nil` when iOS refuses.
    static func icon(bundleID: String, scale: CGFloat) -> UIImage? {
        guard
            let function = iconFunction,
            let imageClass = NSClassFromString("UIImage")
        else { return nil }

        let selector = NSSelectorFromString(iconSelectorName)
        return function(imageClass, selector, bundleID as NSString, 0, scale)?
            .takeUnretainedValue()
    }

    // MARK: - Runtime plumbing

    private typealias WorkspaceFactory = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
    private typealias IconFunction = @convention(c) (AnyClass, Selector, NSString, Int32, CGFloat) -> Unmanaged<UIImage>?

    private static let iconSelectorName = "_applicationIconImageForBundleIdentifier:format:scale:"

    private static let workspaceClass: AnyClass? = {
        openCandidateFrameworks()
        return NSClassFromString("LSApplicationWorkspace")
    }()

    /// `NSClassFromString`/`class_getClassMethod` only see what is already loaded. The
    /// LibraryServices classes live in `MobileCoreServices` and the icon category in
    /// `MobileIcons`; neither is guaranteed to be mapped into a third party process, so the
    /// candidates are opened first. A path that does not exist is simply skipped.
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

    private static let listSelector: Selector? = {
        guard let cls = workspaceClass else { return nil }

        for name in ["allInstalledApplications", "installedApplications", "allApplications"] {
            let selector = NSSelectorFromString(name)
            if class_getInstanceMethod(cls, selector) != nil {
                return selector
            }
        }
        return nil
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

    private static func string(_ object: NSObjectProtocol, _ name: String) -> String? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? String
    }
}
