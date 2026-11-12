import SwiftUI

/// iOS does not let an app read how much space other apps take: the list below is a
/// demo dataset so the UI can show realistic numbers. Everything the app *can* measure
/// (device capacity, its own bundle and container, the file browser) is real.
///
/// Each non-Apple row carries `bundleID`, which is what `AppIconLoader` uses to show the real
/// icon: the icon of the app installed on this device (installed-apps mode), a hand-cut PNG
/// from `Resources/AppIcons`, or the official App Store artwork. Photos, this app's own entry
/// and the fictional ones have no store page and keep the gradient placeholder.
enum DemoCatalog {
    private static let gb: Double = 1_000_000_000

    static let apps: [AppItem] = [
        AppItem(
            id: "photos",
            name: "Photos",
            developer: "Apple",
            version: "9.0",
            symbol: "photo.on.rectangle.angled",
            tint: [Color(hex: 0xFFB800), Color(hex: 0xFF375F), Color(hex: 0x1E6BF1)],
            appSize: makeGB(0.42),
            dataSize: makeGB(15.74),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "feather",
            name: "Feather",
            developer: "Feather Team",
            version: "3.1.4",
            symbol: "paintbrush.pointed.fill",
            tint: [Color(hex: 0x8B87FF), Color(hex: 0x5E5CE6)],
            appSize: makeGB(0.21),
            dataSize: makeGB(9.23),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "telegram",
            bundleID: "ph.telegra.Telegraph",
            name: "Telegram",
            developer: "Telegram FZ-LLC",
            version: "13.1.2",
            symbol: "paperplane.fill",
            tint: [Color(hex: 0x2AABEE), Color(hex: 0x229ED9)],
            appSize: 157_100_000,
            dataSize: makeGB(9.03),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "tiktok",
            bundleID: "com.zhiliaoapp.musically",
            name: "TikTok",
            developer: "TikTok Pte. Ltd.",
            version: "37.2.0",
            symbol: "music.note",
            tint: [Color(hex: 0x25F4EE), Color(hex: 0x161616), Color(hex: 0xFE2C55)],
            appSize: makeGB(0.35),
            dataSize: makeGB(8.56),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "whatsapp",
            bundleID: "net.whatsapp.WhatsApp",
            name: "WhatsApp",
            developer: "Meta Platforms",
            version: "25.9.1",
            symbol: "phone.fill",
            tint: [Color(hex: 0x25D366), Color(hex: 0x128C7E)],
            appSize: makeGB(0.29),
            dataSize: makeGB(6.92),
            lastUsed: "11/10/26",
            isReal: false
        ),
        AppItem(
            id: "youtube",
            bundleID: "com.google.ios.youtube",
            name: "YouTube",
            developer: "Google LLC",
            version: "20.41.4",
            symbol: "play.rectangle.fill",
            tint: [Color(hex: 0xFF0000), Color(hex: 0xC10000)],
            appSize: makeGB(0.24),
            dataSize: makeGB(2.82),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "clash",
            bundleID: "com.supercell.magic",
            name: "Clash of Clans",
            developer: "Supercell",
            version: "17.120.3",
            symbol: "crown.fill",
            tint: [Color(hex: 0xFFB627), Color(hex: 0xC77800)],
            appSize: makeGB(0.42),
            dataSize: makeGB(2.61),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "google",
            bundleID: "com.google.GoogleMobile",
            name: "Google",
            developer: "Google LLC",
            version: "368.0",
            symbol: "g.circle.fill",
            tint: [Color(hex: 0x4285F4), Color(hex: 0xEA4335)],
            appSize: makeGB(0.31),
            dataSize: makeGB(2.57),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "nc",
            name: "NC v18.600.7",
            developer: "NCSOFT",
            version: "18.600.7",
            symbol: "shield.lefthalf.filled",
            tint: [Color(hex: 0x7C4DFF), Color(hex: 0x311B92)],
            appSize: makeGB(0.40),
            dataSize: makeGB(2.38),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "spotify",
            bundleID: "com.spotify.client",
            name: "Spotify",
            developer: "Spotify AB",
            version: "9.0.62",
            symbol: "waveform",
            tint: [Color(hex: 0x1DB954), Color(hex: 0x14833B)],
            appSize: makeGB(0.18),
            dataSize: makeGB(2.13),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "instagram",
            bundleID: "com.burbn.instagram",
            name: "Instagram",
            developer: "Meta Platforms",
            version: "364.0",
            symbol: "camera.fill",
            tint: [Color(hex: 0xF58529), Color(hex: 0xDD2A7B), Color(hex: 0x8134AF)],
            appSize: makeGB(0.22),
            dataSize: makeGB(1.72),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "netflix",
            bundleID: "com.netflix.Netflix",
            name: "Netflix",
            developer: "Netflix, Inc.",
            version: "17.4.0",
            symbol: "n.square.fill",
            tint: [Color(hex: 0xE50914), Color(hex: 0x8B0000)],
            appSize: makeGB(0.30),
            dataSize: makeGB(1.12),
            lastUsed: "08/10/26",
            isReal: false
        ),
        AppItem(
            id: "discord",
            bundleID: "com.hammerandchisel.discord",
            name: "Discord",
            developer: "Discord Inc.",
            version: "260.0",
            symbol: "bubble.left.and.bubble.right.fill",
            tint: [Color(hex: 0x5865F2), Color(hex: 0x404EED)],
            appSize: makeGB(0.19),
            dataSize: makeGB(0.96),
            lastUsed: "Today",
            isReal: false
        ),
        AppItem(
            id: "minecraft",
            bundleID: "com.mojang.minecraftpe",
            name: "Minecraft",
            developer: "Mojang",
            version: "1.21.60",
            symbol: "cube.fill",
            tint: [Color(hex: 0x7BB661), Color(hex: 0x4A7A34)],
            appSize: makeGB(0.36),
            dataSize: makeGB(0.62),
            lastUsed: "05/10/26",
            isReal: false
        )
    ]

    private static func makeGB(_ value: Double) -> Int64 {
        Int64((value * gb).rounded())
    }
}
