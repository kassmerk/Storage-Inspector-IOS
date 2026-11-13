import Foundation

/// Keeps the imported app list between launches.
///
/// The list is a few thousand short strings, small enough for `UserDefaults` and — unlike the
/// sandbox caches — it survives an app update. The rows live as one JSON blob under
/// `SettingsKeys.importedApps`.
enum ImportedAppsStore {
    /// How many rows are kept. `AppListParser` already caps a single paste; this caps the saved list.
    static let maximumApps = 4000

    static func load(from defaults: UserDefaults = .standard) -> [ImportedApp] {
        guard let data = defaults.data(forKey: SettingsKeys.importedApps) else { return [] }
        guard let apps = try? JSONDecoder().decode([ImportedApp].self, from: data) else { return [] }
        return apps
    }

    static func save(_ apps: [ImportedApp], to defaults: UserDefaults = .standard) {
        let trimmed = Array(apps.prefix(maximumApps))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: SettingsKeys.importedApps)
    }

    /// Merges a freshly parsed list into the saved one. A row with the same id is replaced, so
    /// importing a newer export updates names, versions and sizes instead of duplicating rows; a
    /// missing number never overwrites one that is already there.
    @discardableResult
    static func merge(_ incoming: [ImportedApp], into defaults: UserDefaults = .standard) -> [ImportedApp] {
        var merged = load(from: defaults)
        var index: [String: Int] = [:]
        for (position, app) in merged.enumerated() { index[app.id] = position }

        for app in incoming {
            if let position = index[app.id] {
                var existing = merged[position]
                if !app.name.isEmpty { existing.name = app.name }
                if let version = app.version { existing.version = version }
                if let size = app.appSize { existing.appSize = size }
                if let size = app.dataSize { existing.dataSize = size }
                merged[position] = existing
            } else {
                index[app.id] = merged.count
                merged.append(app)
            }
        }

        let result = Array(merged.prefix(maximumApps))
        save(result, to: defaults)
        return result
    }

    @discardableResult
    static func remove(id: String, from defaults: UserDefaults = .standard) -> [ImportedApp] {
        var apps = load(from: defaults)
        apps.removeAll { $0.id == id }
        save(apps, to: defaults)
        return apps
    }

    @discardableResult
    static func clear(from defaults: UserDefaults = .standard) -> [ImportedApp] {
        defaults.removeObject(forKey: SettingsKeys.importedApps)
        return []
    }
}
