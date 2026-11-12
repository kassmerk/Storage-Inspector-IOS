import SwiftUI

/// "App Icon" card of the Settings screen — one tile per bundled icon colour.
struct AppIconCard: View {
    @StateObject private var manager = AppIconManager()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppIconStyle.allCases) { style in
                    tile(style)
                }
            }

            footer
        }
        .cardStyle(padding: 16)
        .alert("Could not change the icon", isPresented: errorPresented) {
            Button("OK", role: .cancel) {
                manager.errorMessage = nil
            }
        } message: {
            Text(manager.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)

            Text("App Icon")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text(manager.current.title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    private func tile(_ style: AppIconStyle) -> some View {
        let selected = manager.current == style

        return Button {
            manager.apply(style)
        } label: {
            VStack(spacing: 8) {
                AppIconPreview(style: style, selected: selected)
                Text(style.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .white : Theme.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .opacity(manager.isApplying && !selected ? 0.5 : 1)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(manager.isApplying)
    }

    private var footer: some View {
        Group {
            if manager.isSupported {
                Text("iOS shows a short system alert when the icon changes. Home Screen and App Switcher update right away.")
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.yellow)
                    Text("This build has no alternate icons inside, so the picker is disabled. The packaging script adds them — see the README.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.tertiaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { manager.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    manager.errorMessage = nil
                }
            }
        )
    }
}

/// Square preview of a shipped icon, drawn with shapes so no extra image assets are needed.
struct AppIconPreview: View {
    let style: AppIconStyle
    var selected: Bool = false
    var size: CGFloat = 62

    private var radius: CGFloat { size * 0.235 }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: style.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                AppIconGlyph()
                    .frame(width: size, height: size)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        selected ? Theme.accent : Color.white.opacity(0.12),
                        lineWidth: selected ? 2.4 : 0.8
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size * 0.27, weight: .bold))
                        .foregroundStyle(.white, Theme.accent)
                        .background {
                            Circle()
                                .fill(Theme.background)
                                .padding(1.6)
                        }
                        .offset(x: size * 0.06, y: size * 0.06)
                }
            }
    }
}

/// The white "storage tag" glyph of the app icon: a rounded roof plus a capsule with a hole.
struct AppIconGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.255, y: h * 0.468))
                    path.addLine(to: CGPoint(x: w * 0.318, y: h * 0.332))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.378, y: h * 0.300),
                        control: CGPoint(x: w * 0.330, y: h * 0.300)
                    )
                    path.addLine(to: CGPoint(x: w * 0.622, y: h * 0.300))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.682, y: h * 0.332),
                        control: CGPoint(x: w * 0.670, y: h * 0.300)
                    )
                    path.addLine(to: CGPoint(x: w * 0.745, y: h * 0.468))
                    path.closeSubpath()
                }
                .fill(Color.white)

                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: w * 0.490, height: h * 0.185)
                    .position(x: w * 0.500, y: h * 0.578)

                Circle()
                    .fill(Color.white)
                    .frame(width: w * 0.076, height: w * 0.076)
                    .position(x: w * 0.632, y: h * 0.578)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

struct AppIconCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            AppIconCard()
                .padding(16)
        }
        .preferredColorScheme(.dark)
    }
}
