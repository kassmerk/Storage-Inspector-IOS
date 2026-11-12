import SwiftUI

/// Central place for the "iOS Settings / Feather" inspired dark palette.
enum Theme {
    static let background = Color(hex: 0x000000)
    static let card = Color(hex: 0x1C1C1E)
    static let cardElevated = Color(hex: 0x2C2C2E)
    static let separator = Color.white.opacity(0.08)

    static let accent = Color(hex: 0x8B87FF)
    static let indigo = Color(hex: 0x5E5CE6)

    static let secondaryLabel = Color(hex: 0x9A9A9F)
    static let tertiaryLabel = Color(hex: 0x6E6E73)

    static let blue = Color(hex: 0x0A84FF)
    static let red = Color(hex: 0xFF453A)
    static let green = Color(hex: 0x30D158)
    static let orange = Color(hex: 0xFF9F0A)
    static let yellow = Color(hex: 0xFFD60A)
    static let pink = Color(hex: 0xFF6482)
    static let teal = Color(hex: 0x40C8C0)

    /// Corner radius used by the rounded cards.
    static let cardRadius: CGFloat = 26
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

extension View {
    /// Rounded dark card, the main building block of every screen.
    func cardStyle(padding: CGFloat = 16, radius: CGFloat = Theme.cardRadius) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.card)
            )
    }
}
