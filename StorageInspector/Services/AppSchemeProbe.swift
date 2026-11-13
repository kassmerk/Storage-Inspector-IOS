import SwiftUI
import UIKit

/// Which apps of a fixed, hand-picked list are on this iPhone — the only honest way to name other
/// apps without elevated signing.
///
/// A normally signed app (Feather with a certificate, a developer build, the App Store) gets
/// **zero** rows from LaunchServices: iOS keeps that database and every per-app size closed to it,
/// and no code can open it. The entitlement that does (`platform-application`) is issued only to
/// TrollStore / jailbroken installs, and iOS 26 has neither, so a sandboxed build has to ask about
/// specific apps instead of asking for a list.
///
/// Two channels are left, and this type tries both for every candidate:
///
/// * `-[LSApplicationWorkspace applicationProxyForIdentifier:]` — a question about one bundle id
///   instead of the whole list. It answers whenever this iOS build still resolves single bundles,
///   and it needs nothing declared anywhere;
/// * `UIApplication.canOpenURL` on a scheme the app registers — the system answers that for any
///   app, but only for the schemes listed in `LSApplicationQueriesSchemes` (max 50 per app, and
///   they live in `Resources/Info.plist`).
///
/// What stays unknown, and what the UI says out loud: the size of an app found this way, and any
/// app that registers none of the probed schemes. A candidate that neither channel confirms is
/// simply left out — nothing here is guessed.
enum AppSchemeProbe {
    /// One app that can be looked for, plus the scheme its `.ipa` registers.
    struct Candidate {
        let name: String
        let developer: String
        let bundleID: String
        let scheme: String
    }

    /// 44 apps: below Apple's 50-scheme ceiling for `canOpenURL`, and the list `Resources/Info.plist`
    /// declares. Adding a candidate means adding its scheme to that array as well, or the
    /// `canOpenURL` channel answers `false` for it forever.
    static let candidates: [Candidate] = [
        Candidate(name: "Telegram", developer: "Telegram FZ-LLC", bundleID: "org.telegram.iphone", scheme: "tg"),
        Candidate(name: "WhatsApp", developer: "Meta Platforms", bundleID: "net.whatsapp.WhatsApp", scheme: "whatsapp"),
        Candidate(name: "Instagram", developer: "Meta Platforms", bundleID: "com.burbn.instagram", scheme: "instagram"),
        Candidate(name: "TikTok", developer: "TikTok Pte. Ltd.", bundleID: "com.zhiliaoapp.musically", scheme: "snssdk1128"),
        Candidate(name: "YouTube", developer: "Google LLC", bundleID: "com.google.ios.youtube", scheme: "youtube"),
        Candidate(name: "Spotify", developer: "Spotify", bundleID: "com.spotify.client", scheme: "spotify"),
        Candidate(name: "Facebook", developer: "Meta Platforms", bundleID: "com.facebook.Facebook", scheme: "fb"),
        Candidate(name: "Messenger", developer: "Meta Platforms", bundleID: "com.facebook.Messenger", scheme: "fb-messenger"),
        Candidate(name: "Snapchat", developer: "Snap Inc.", bundleID: "com.toyopagroup.picaboo", scheme: "snapchat"),
        Candidate(name: "X", developer: "X Corp.", bundleID: "com.atebits.Tweetie2", scheme: "twitter"),
        Candidate(name: "Discord", developer: "Discord Inc.", bundleID: "com.hammerandchisel.discord", scheme: "discord"),
        Candidate(name: "Reddit", developer: "Reddit", bundleID: "com.reddit.Reddit", scheme: "reddit"),
        Candidate(name: "Netflix", developer: "Netflix, Inc.", bundleID: "com.netflix.Netflix", scheme: "nflx"),
        Candidate(name: "Google Maps", developer: "Google LLC", bundleID: "com.google.Maps", scheme: "comgooglemaps"),
        Candidate(name: "Waze", developer: "Waze", bundleID: "com.waze.iphone", scheme: "waze"),
        Candidate(name: "Chrome", developer: "Google LLC", bundleID: "com.google.chrome.ios", scheme: "googlechrome"),
        Candidate(name: "Gmail", developer: "Google LLC", bundleID: "com.google.Gmail", scheme: "googlegmail"),
        Candidate(name: "Google Drive", developer: "Google LLC", bundleID: "com.google.Drive", scheme: "googledrive"),
        Candidate(name: "Google Photos", developer: "Google LLC", bundleID: "com.google.photos", scheme: "googlephotos"),
        Candidate(name: "Uber", developer: "Uber Technologies", bundleID: "com.ubercab.UberClient", scheme: "uber"),
        Candidate(name: "Bolt", developer: "Bolt Technology", bundleID: "ee.mtakso.client", scheme: "bolt"),
        Candidate(name: "Viber", developer: "Rakuten Viber", bundleID: "com.viber", scheme: "viber"),
        Candidate(name: "Signal", developer: "Signal Messenger", bundleID: "org.whispersystems.signal", scheme: "sgnl"),
        Candidate(name: "WeChat", developer: "Tencent", bundleID: "com.tencent.xin", scheme: "weixin"),
        Candidate(name: "VK", developer: "VK", bundleID: "com.vk.vkclient", scheme: "vk"),
        Candidate(name: "Zoom", developer: "Zoom Video", bundleID: "us.zoom.xos", scheme: "zoomus"),
        Candidate(name: "Slack", developer: "Slack Technologies", bundleID: "com.tinyspeck.chatlyio", scheme: "slack"),
        Candidate(name: "Notion", developer: "Notion Labs", bundleID: "notion.id", scheme: "notion"),
        Candidate(name: "Outlook", developer: "Microsoft", bundleID: "com.microsoft.Outlook", scheme: "ms-outlook"),
        Candidate(name: "Teams", developer: "Microsoft", bundleID: "com.microsoft.skype.teams", scheme: "msteams"),
        Candidate(name: "Word", developer: "Microsoft", bundleID: "com.microsoft.Office.Word", scheme: "ms-word"),
        Candidate(name: "Excel", developer: "Microsoft", bundleID: "com.microsoft.Office.Excel", scheme: "ms-excel"),
        Candidate(name: "OneDrive", developer: "Microsoft", bundleID: "com.microsoft.skydrive", scheme: "ms-onedrive"),
        Candidate(name: "Steam", developer: "Valve", bundleID: "com.valvesoftware.steam", scheme: "steam"),
        Candidate(name: "Twitch", developer: "Twitch Interactive", bundleID: "tv.twitch", scheme: "twitch"),
        Candidate(name: "Shazam", developer: "Apple", bundleID: "com.shazam.Shazam", scheme: "shazam"),
        Candidate(name: "Duolingo", developer: "Duolingo", bundleID: "com.duolingo.DuolingoMobile", scheme: "duolingo"),
        Candidate(name: "Roblox", developer: "Roblox Corporation", bundleID: "com.roblox.robloxmobile", scheme: "roblox"),
        Candidate(name: "Minecraft", developer: "Mojang", bundleID: "com.mojang.minecraftpe", scheme: "minecraft"),
        Candidate(name: "Clash of Clans", developer: "Supercell", bundleID: "com.supercell.magic", scheme: "clashofclans"),
        Candidate(name: "Brawl Stars", developer: "Supercell", bundleID: "com.supercell.laser", scheme: "brawlstars"),
        Candidate(name: "Clash Royale", developer: "Supercell", bundleID: "com.supercell.scroll", scheme: "clashroyale"),
        Candidate(name: "Airbnb", developer: "Airbnb, Inc.", bundleID: "com.airbnb.app", scheme: "airbnb"),
        Candidate(name: "Booking.com", developer: "Booking.com", bundleID: "com.booking", scheme: "booking"),
    ]

    /// The schemes this build declares. Empty means the `Info.plist` key was lost — the
    /// `canOpenURL` channel then answers `false` for every third-party scheme, which is why the
    /// Settings screen prints this count instead of leaving the user with an empty list.
    static var declaredSchemes: [String] {
        (Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]) ?? []
    }

    static var isConfigured: Bool { !declaredSchemes.isEmpty }

    /// `true` when at least one of the two channels can answer at all.
    static var isAvailable: Bool { InstalledAppsProvider.isAvailable || isConfigured }

    /// The candidates this iPhone answered for, as rows the Storage screen can show.
    ///
    /// Runs on the main thread: `canOpenURL` is a UIKit call and the 44 checks are synchronous.
    /// Sizes stay unknown (`hasKnownAppSize` / `hasKnownDataSize` are `false`), so the UI prints a
    /// dash instead of a zero.
    static func detect() -> [AppItem] {
        candidates.compactMap { candidate -> AppItem? in
            guard isPresent(candidate) else { return nil }

            return AppItem(
                id: candidate.bundleID,
                bundleID: candidate.bundleID,
                name: candidate.name,
                developer: candidate.developer,
                version: "—",
                symbol: "app.dashed",
                tint: [Theme.cardElevated, Theme.card],
                appSize: 0,
                dataSize: 0,
                lastUsed: "—",
                isReal: true,
                hasKnownAppSize: false,
                hasKnownDataSize: false,
                isDetectedOnly: true
            )
        }
    }

    /// Asks the LaunchServices class first (no declaration needed) and falls back to the URL
    /// scheme. Both are cheap and neither one can produce a false positive: iOS only says `true`
    /// for an app that is really installed.
    private static func isPresent(_ candidate: Candidate) -> Bool {
        if InstalledAppsProvider.isBundlePresent(candidate.bundleID) { return true }
        guard let url = URL(string: candidate.scheme + "://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
