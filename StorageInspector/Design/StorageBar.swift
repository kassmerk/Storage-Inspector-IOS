import SwiftUI

/// Segmented storage bar: one colored slice per category.
struct StorageSegment: Identifiable {
    let id: String
    let color: Color
    let bytes: Int64
}

struct StorageBar: View {
    let segments: [StorageSegment]
    let total: Int64
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let visible = segments.filter { total > 0 && ratio($0.bytes) > 0.004 }
            let available = max(0, proxy.size.width - spacing * CGFloat(max(0, visible.count - 1)))

            HStack(spacing: spacing) {
                ForEach(visible) { segment in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(segment.color)
                        .frame(width: max(3, available * ratio(segment.bytes)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func ratio(_ bytes: Int64) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(Double(bytes) / Double(total))
    }
}

/// Custom navigation header: round back button on the left, centered title.
struct DetailTopBar: View {
    let title: String
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 60)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(white: 0.16)))
                }
                .buttonStyle(PressableCardStyle())

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(Theme.background)
    }
}

/// Card shown when a folder is empty.
struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.tertiaryLabel)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressableCardStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}
