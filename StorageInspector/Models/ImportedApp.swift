import Foundation

/// One row of an app list that was brought over from a computer.
///
/// On iOS 26 a sandboxed build cannot ask iOS for the installed apps (see `AppSchemeProbe`), so the
/// only way to show *every* app is a list produced by something that is allowed to see them: the
/// `ideviceinstaller` output of a paired Mac or PC, an export from a desktop tool, or a copy of the
/// Settings › General › iPhone Storage screen. `ImportedApp` is one line of that text after
/// `AppListParser` has read it: a bundle id when the text had one, a name, and a size when the text
/// carried a size. Nothing is filled in for a field the text did not have.
struct ImportedApp: Codable, Hashable, Identifiable {
    /// `nil` when the source text had no bundle id — the iPhone Storage screen has none.
    var bundleID: String?
    var name: String
    var version: String?
    /// Size of the app bundle, only when the imported text reported it.
    var appSize: Int64?
    /// Documents & Data, only when the imported text reported it.
    var dataSize: Int64?

    /// The bundle id is the identity when there is one, otherwise the normalized name.
    var id: String { bundleID ?? "name:" + ImportedApp.key(name) }

    /// `true` when at least one number came with the text, so the row can show a real size.
    var hasKnownSize: Bool { appSize != nil || dataSize != nil }

    /// `Telegram` and `telegram ` count as the same row when the list has no bundle ids.
    static func key(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
