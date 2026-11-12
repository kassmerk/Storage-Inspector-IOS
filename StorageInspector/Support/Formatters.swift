import Foundation

/// How sizes are rendered across the app.
enum SizeUnit: String, CaseIterable, Identifiable {
    case automatic
    case gigabytes
    case megabytes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .gigabytes: return "Gigabytes (GB)"
        case .megabytes: return "Megabytes (MB)"
        }
    }

    var shortTitle: String {
        switch self {
        case .automatic: return "Auto"
        case .gigabytes: return "GB"
        case .megabytes: return "MB"
        }
    }
}

/// `@AppStorage` keys, kept in one place so every screen reads the same values.
enum SettingsKeys {
    static let sizeUnit = "storageInspector.sizeUnit"
    static let showDemoApps = "storageInspector.showDemoApps"
    /// Makes the scan list Apple's hidden system services as well (off by default).
    static let showHiddenApps = "storageInspector.showHiddenApps"
}

enum Formatters {
    static func bytes(_ value: Int64, unit: SizeUnit = .automatic) -> String {
        if value <= 0 {
            switch unit {
            case .gigabytes: return "0 GB"
            case .megabytes, .automatic: return "0 MB"
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = unit == .automatic

        switch unit {
        case .automatic:
            formatter.allowedUnits = [.useGB, .useMB]
        case .gigabytes:
            formatter.allowedUnits = [.useGB]
        case .megabytes:
            formatter.allowedUnits = [.useMB]
        }

        return formatter.string(fromByteCount: max(0, value))
    }

    static func date(_ value: Date?) -> String {
        guard let value = value else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy HH:mm"
        return formatter.string(from: value)
    }

    /// A size, or an em dash when iOS keeps it private (every app except this one).
    static func size(_ value: Int64, known: Bool, unit: SizeUnit = .automatic) -> String {
        known ? bytes(value, unit: unit) : "—"
    }

    /// "1.0 (1)" — short version plus build number.
    static func version() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info["CFBundleVersion"] as? String) ?? "1"
        return "\(short) (\(build))"
    }
}
