import SwiftUI
import UIKit

/// Left aligned big title, like the "Settings" header in iOS.
struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Slight fade + scale on tap, used by every custom button.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Rounded icon tile: the resolved picture when `AppIconLoader` has one (icon of the installed
/// app, a bundled PNG or the App Store artwork), otherwise a gradient stand-in with an SF Symbol.
struct AppIconView: View {
    let symbol: String
    let tint: [Color]
    var size: CGFloat = 52
    var cornerRadius: CGFloat? = nil
    /// Resolved picture; `nil` keeps the placeholder.
    var artwork: UIImage? = nil

    private var radius: CGFloat { cornerRadius ?? size * 0.26 }

    var body: some View {
        ZStack {
            if let artwork = artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }
}

struct Separator: View {
    var leading: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.7)
            .padding(.leading, leading)
    }
}

/// "App Size ........ 157.1 MB" style row.
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Theme.secondaryLabel)
                .monospacedDigit()
        }
        .font(.system(size: 17))
        .padding(.vertical, 13)
    }
}

/// Big rounded button used for "Offload App" / "Delete App" / "Donate".
struct ActionButton: View {
    enum Kind {
        case primary
        case standard
        case destructive
    }

    let title: String
    var kind: Kind = .standard
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: kind == .primary ? .semibold : .regular))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(kind == .primary ? Theme.accent : Theme.card)
                )
        }
        .buttonStyle(PressableCardStyle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .standard: return Theme.blue
        case .destructive: return Theme.red
        }
    }
}

/// Rounded search field pinned above the tab bar.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.secondaryLabel)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundColor(Theme.secondaryLabel)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.white)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.tertiaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 17))
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
