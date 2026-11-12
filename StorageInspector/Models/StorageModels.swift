import Foundation
import SwiftUI

/// One application row on the Storage screen.
struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let developer: String
    let version: String
    /// SF Symbol used as a stand-in for the real app icon.
    let symbol: String
    /// Two or three colors of the icon gradient.
    let tint: [Color]
    /// Size of the app bundle itself.
    let appSize: Int64
    /// Size of Documents & Data (container size minus bundle).
    let dataSize: Int64
    let lastUsed: String
    /// `true` for numbers that were really measured on this device.
    let isReal: Bool

    var totalSize: Int64 { appSize + dataSize }

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
