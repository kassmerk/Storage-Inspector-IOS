import SwiftUI

/// App icon colour variants shipped inside the bundle.
///
/// `orange` is the primary icon (the one in `Assets.xcassets/AppIcon`), the other three are
/// alternate icons declared in `CFBundleAlternateIcons` and applied with
/// `UIApplication.setAlternateIconName(_:)`. The 1024x1024 sources live in
/// `StorageInspector/Resources/AppIconVariants/`, a folder reference: the same PNGs ship inside
/// the `.app` (so the Settings picker draws them, see `AppIconArtwork`) and the packaging step
/// resizes them into `Icon*.png` files for `CFBundleAlternateIcons`.
enum AppIconStyle: String, CaseIterable, Identifiable {
    case orange
    case indigo
    case graphite
    case crimson

    var id: String { rawValue }

    /// Name handed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` means "restore the primary icon", which is the orange one.
    var alternateName: String? {
        switch self {
        case .orange: return nil
        case .indigo: return "IconIndigo"
        case .graphite: return "IconGraphite"
        case .crimson: return "IconCrimson"
        }
    }

    /// File name (without `.png`) of the 1024x1024 source in `Resources/AppIconVariants`.
    var sourceName: String {
        switch self {
        case .orange: return "icon-orange"
        case .indigo: return "icon-indigo"
        case .graphite: return "icon-graphite"
        case .crimson: return "icon-crimson"
        }
    }

    var title: String {
        switch self {
        case .orange: return "Orange"
        case .indigo: return "Indigo"
        case .graphite: return "Graphite"
        case .crimson: return "Crimson"
        }
    }

    /// Diagonal gradient of the shipped PNG, used for the in-app preview tiles.
    var gradient: [Color] {
        switch self {
        case .orange: return [Color(hex: 0xFFA320), Color(hex: 0xFF4A00)]
        case .indigo: return [Color(hex: 0x7C79F2), Color(hex: 0x5B57E0)]
        case .graphite: return [Color(hex: 0x2E2E31), Color(hex: 0x0A0A0C)]
        case .crimson: return [Color(hex: 0xAE0016), Color(hex: 0x140608)]
        }
    }

    /// Maps the value returned by `UIApplication.shared.alternateIconName` back to a style.
    static func style(forAlternateName name: String?) -> AppIconStyle {
        guard let name = name else { return .orange }
        return allCases.first { $0.alternateName == name } ?? .orange
    }
}
