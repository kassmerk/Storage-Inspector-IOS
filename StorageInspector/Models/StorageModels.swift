import Foundation
import SwiftUI

/// One application row on the Storage screen.
struct AppItem: Identifiable, Hashable {
    let id: String
    /// Bundle identifier, when known: it is what `AppIconLoader` looks the icon up with
    /// (the icon of the installed app, the App Store artwork, or a bundled PNG).
    var bundleID: String? = nil
    let name: String
    let developer: String
    let version: String
    /// SF Symbol used as a stand-in when no picture could be resolved.
    let symbol: String
    /// Two or three colors of the icon gradient behind that symbol.
    let tint: [Color]
    /// Size of the app bundle itself.
    let appSize: Int64
    /// Size of Documents & Data (container size minus bundle).
    let dataSize: Int64
    let lastUsed: String
    /// `true` for names that come from the device itself (this app, or the real apps list).
    let isReal: Bool
    /// `false` when iOS hides the size of the app bundle itself. The UI shows a dash then.
    var hasKnownAppSize: Bool = true
    /// `false` when iOS hides the size of Documents & Data. The UI shows a dash then.
    var hasKnownDataSize: Bool = true

    var totalSize: Int64 { appSize + dataSize }

    /// `true` when iOS reported at least one of the two numbers. Only the size of this app is
    /// always known; for the other apps it depends on what the private disk-usage getters answer.
    var hasKnownSize: Bool { hasKnownAppSize || hasKnownDataSize }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Whole-device capacity, read from the file system.
struct DeviceCapacity {
    var total: Int64
    var available: Int64

    var used: Int64 { max(0, total - available) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static let empty = DeviceCapacity(total: 0, available: 0)
}

/// One file or folder inside the app sandbox.
struct SandboxEntry: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date?

    var id: String { url.absoluteString }

    static func == (lhs: SandboxEntry, rhs: SandboxEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A top level sandbox folder (Documents / Library / tmp).
struct SandboxRoot: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let url: URL
}

enum SizeSortMode: String, CaseIterable {
    case size
    case name

    var title: String {
        switch self {
        case .size: return "Size"
        case .name: return "Name"
        }
    }
}
