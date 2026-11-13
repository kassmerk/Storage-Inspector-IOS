import Foundation

/// Reads the app lists people paste in or import from a file.
///
/// There is no canonical format for "the apps on my iPhone", so the parser accepts the shapes the
/// real sources produce:
///
/// * `com.burbn.instagram - Instagram (312.1.0)` — the `ideviceinstaller -l -o list_all` output of
///   a paired Mac or PC;
/// * `com.burbn.instagram,Instagram,312.1.0,214 MB` — a CSV export from a desktop tool (comma,
///   semicolon or tab separated, columns in any order);
/// * `Instagram` followed by `2.14 GB` on the next line — a copy of Settings › General ›
///   iPhone Storage.
///
/// A header line and a `Total: 42 apps` line are ignored instead of becoming rows, and a line that
/// cannot be read as an app (prose, an empty line, a stray word) is dropped: nothing is invented to
/// fill a gap. Sizes are taken only from the text, never guessed.
enum AppListParser {
    struct Result {
        var apps: [ImportedApp] = []
        /// Lines that carried no app: blanks, headers, "Total: …", prose.
        var skipped: Int = 0

        var isEmpty: Bool { apps.isEmpty }
    }

    /// Upper bound, so a wrong paste cannot fill the defaults database.
    private static let maximumApps = 4000

    static func parse(_ raw: String) -> Result {
        // A list saved by a Windows tool may start with a byte-order mark. It is not part of the
        // first line, and it would hide the column header from `isHeader`.
        let text = raw.replacingOccurrences(of: "\u{FEFF}", with: "")

        var result = Result()
        let lines = text.components(separatedBy: .newlines)
        // A list with no bundle id at all (`Settings › iPhone Storage` copies) has to accept bare
        // names; a list that does carry bundle ids must not, or every stray word becomes a row.
        let containsBundleID = lines.contains { line in
            firstToken(of: line).map(isBundleID) ?? false
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }
            if isHeader(line) || isFooter(line) {
                result.skipped += 1
                continue
            }

            if let app = parseLine(line, namesOnlyAllowed: !containsBundleID) {
                result.apps.append(app)
                continue
            }

            // A bare size line belongs to the name above it — that is how the iPhone Storage
            // screen copies out ("Telegram", then "2.14 GB").
            if var last = result.apps.last, !last.hasKnownSize, let size = size(from: line) {
                last.appSize = size
                result.apps[result.apps.count - 1] = last
                continue
            }

            result.skipped += 1
        }

        result.apps = deduplicated(result.apps)
        return result
    }

    // MARK: - One line

    private static func parseLine(_ line: String, namesOnlyAllowed: Bool) -> ImportedApp? {
        if let app = parseColumns(line) { return app }

        var bundleID: String?
        var rest = line

        if let token = firstToken(of: line), isBundleID(token), let tail = restAfterFirstToken(line) {
            bundleID = token
            rest = tail
        }

        var version: String?
        if let quoted = quotedName(rest) {
            // Two orders exist: `1.2.3 "Instagram"` (the quoted part is the name) and
            // `Instagram, "1.2.3"` (the quoted part is the version). The second one used to be read
            // as the first, which left a version where the name belongs — and a name without a
            // letter is rejected, so the whole app line disappeared from the list.
            let outside = rest.replacingOccurrences(of: "\"\(quoted)\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",-:—–"))

            if isVersion(quoted) {
                version = quoted
                rest = outside
            } else {
                if isVersion(outside) { version = outside }
                rest = quoted
            }
        } else if let split = leadingVersion(rest) {
            version = split.version
            rest = split.rest
        }

        if version == nil, let bracketed = trailingBracketVersion(rest) {
            version = bracketed.version
            rest = bracketed.rest
        }

        var appSize: Int64?
        if let trailing = trailingSize(rest) {
            appSize = trailing.value
            rest = trailing.rest
        }

        let name = clean(rest)
        guard isPlausibleName(name) else { return nil }
        // Without a bundle id or a size the line could be anything, unless the whole paste has no
        // bundle ids at all — then it is a name-only list and the name is the row.
        guard bundleID != nil || appSize != nil || namesOnlyAllowed else { return nil }

        return ImportedApp(
            bundleID: bundleID,
            name: name,
            version: version,
            appSize: appSize,
            dataSize: nil
        )
    }

    /// `com.foo.bar,Name,1.2.3,214 MB` — the column shape. Columns are classified, not ordered, so
    /// a tool that puts the name first still works.
    private static func parseColumns(_ line: String) -> ImportedApp? {
        let fields = columns(line)
        guard fields.count > 1 else { return nil }

        var bundleID: String?
        var name: String?
        var version: String?
        var appSize: Int64?

        for field in fields {
            if bundleID == nil, isBundleID(field) {
                bundleID = field
            } else if appSize == nil, let size = size(from: field) {
                appSize = size
            } else if version == nil, isVersion(field) {
                version = field
            } else if name == nil {
                let value = clean(field)
                if isPlausibleName(value) { name = value }
            }
        }

        guard let foundID = bundleID, let foundName = name else { return nil }
        return ImportedApp(
            bundleID: foundID,
            name: foundName,
            version: version,
            appSize: appSize,
            dataSize: nil
        )
    }

    // MARK: - Fields

    private static func columns(_ line: String) -> [String] {
        let separators: [Character] = ["\t", ",", ";", "|"]
        for separator in separators {
            guard line.contains(separator) else { continue }
            return line.split(separator: separator, omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    private static func firstToken(of line: String) -> String? {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"',")) }
    }

    /// Everything after the first token, with the `-`, `:` or `,` a list may put there removed.
    private static func restAfterFirstToken(_ line: String) -> String? {
        guard let separator = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
        var rest = Substring(line[separator...]).drop { $0 == " " || $0 == "\t" }
        while let first = rest.first,
              first == "-" || first == "–" || first == "—" || first == ":" || first == "," {
            rest = rest.dropFirst().drop { $0 == " " }
        }
        let text = String(rest).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// `Instagram (312.1.0)` → the version and the name without it.
    private static func trailingBracketVersion(_ text: String) -> (version: String, rest: String)? {
        guard text.hasSuffix(")"), let open = text.lastIndex(of: "(") else { return nil }
        let inside = String(text[text.index(after: open)..<text.index(before: text.endIndex)])
        guard isVersion(inside) else { return nil }
        let head = String(text[..<open])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",-:—–"))
        return (inside, head)
    }

    /// `1.2.3 Instagram` → the version and the name without it.
    private static func leadingVersion(_ text: String) -> (version: String, rest: String)? {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, isVersion(String(parts[0])) else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    private static func quotedName(_ text: String) -> String? {
        guard let open = text.firstIndex(of: "\""),
              let close = text.lastIndex(of: "\""),
              open < close else { return nil }
        let inside = String(text[text.index(after: open)..<close])
        return inside.isEmpty ? nil : inside
    }

    /// `Instagram 214 MB` → the size and the name without it.
    private static func trailingSize(_ text: String) -> (value: Int64, rest: String)? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return nil }

        if parts.count >= 2, let value = size(from: parts.suffix(2).joined(separator: " ")) {
            return (value, parts.dropLast(2).joined(separator: " "))
        }
        if let value = size(from: parts[parts.count - 1]) {
            return (value, parts.dropLast(1).joined(separator: " "))
        }
        return nil
    }

    // MARK: - Field kinds

    private static func isBundleID(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, text.contains("."), !text.contains(" ") else { return false }
        guard text.contains(where: { $0.isLetter }) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return !isVersion(text)
    }

    private static func isVersion(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.contains(where: { $0.isNumber }) else { return false }
        let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".vV-()_ "))
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return true
    }

    /// `2.14 GB`, `7,3 ГБ`, `1.2GB`, `214 MB`, `900000000` — anything else is not a size.
    static func size(from raw: String) -> Int64? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        text = text.replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty else { return nil }

        let upper = text.uppercased()
        for unit in sizeUnits {
            guard upper.hasSuffix(unit.suffix) else { continue }
            let number = String(upper.dropLast(unit.suffix.count)).trimmingCharacters(in: .whitespaces)
            guard let value = Double(number), value >= 0 else { return nil }
            return Int64((value * unit.multiplier).rounded())
        }

        // A bare number only counts as bytes when it is big enough to be one.
        if text.count >= 7, let value = Int64(text), value >= 1_000_000 { return value }
        return nil
    }

    /// Longer suffixes are tested first, so `2 GB` is never read as two bytes.
    private static let sizeUnits: [(suffix: String, multiplier: Double)] = [
        ("TB", 1_099_511_627_776), ("ТБ", 1_099_511_627_776),
        ("GB", 1_073_741_824), ("ГБ", 1_073_741_824),
        ("MB", 1_048_576), ("МБ", 1_048_576),
        ("KB", 1024), ("КБ", 1024),
        ("B", 1), ("Б", 1)
    ]

    // MARK: - Name hygiene

    private static func clean(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ",-:;—–"))
        text = text.replacingOccurrences(of: "  ", with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isPlausibleName(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 70 else { return false }
        guard value.contains(where: { $0.isLetter }) else { return false }
        return !stopNames.contains(ImportedApp.key(value))
    }

    /// Words that surround the real app names on the screens people copy from, plus the column
    /// titles of a CSV. A line made of these is not an app.
    private static let stopNames: Set<String> = [
        "lastused", "today", "yesterday", "documentsdata", "appsize", "size", "total",
        "offloadapp", "deleteapp", "iphonestorage", "recommendations", "showall", "name",
        "identifier", "bundleid", "bundleidentifier", "version", "data", "apps", "storage",
        "settings", "general", "used", "free", "installed", "updated", "type", "path"
    ]

    private static func isHeader(_ line: String) -> Bool {
        let fields = columns(line)
        let words = fields.isEmpty
            ? line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            : fields
        guard !words.isEmpty, words.count <= 12 else { return false }
        let headerWords: Set<String> = [
            "identifier", "bundle", "bundleid", "bundleidentifier", "id", "name", "app",
            "appname", "version", "size", "appsize", "data", "documentsdata", "total",
            "staticdiskusage", "dynamicdiskusage", "type", "path"
        ]
        return words.allSatisfy { headerWords.contains(ImportedApp.key($0)) }
    }

    private static func isFooter(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("total:") || lower.hasPrefix("total ") { return true }
        if lower.hasPrefix("found ") || lower.hasPrefix("showing ") { return true }
        return false
    }

    // MARK: - Merge

    /// One row per app: a repeated line keeps the first name and fills the gaps of the first one.
    private static func deduplicated(_ apps: [ImportedApp]) -> [ImportedApp] {
        var order: [String] = []
        var byKey: [String: ImportedApp] = [:]

        for app in apps.prefix(maximumApps) {
            let key = app.id
            if var existing = byKey[key] {
                if existing.version == nil { existing.version = app.version }
                if existing.appSize == nil { existing.appSize = app.appSize }
                if existing.dataSize == nil { existing.dataSize = app.dataSize }
                if existing.name.count < app.name.count { existing.name = app.name }
                byKey[key] = existing
            } else {
                byKey[key] = app
                order.append(key)
            }
        }

        return order.compactMap { byKey[$0] }
    }
}
