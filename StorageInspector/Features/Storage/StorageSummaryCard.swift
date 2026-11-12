import SwiftUI

/// Top card of the Storage screen: capacity, segmented bar and legend.
struct StorageSummaryCard: View {
    let capacity: DeviceCapacity
    let applicationsBytes: Int64
    let unit: SizeUnit

    private var otherBytes: Int64 { max(0, capacity.used - applicationsBytes) }
    private var mediaBytes: Int64 { otherBytes * 6 / 10 }
    private var systemBytes: Int64 { otherBytes - mediaBytes }
    private var freeBytes: Int64 { capacity.available }

    private var segments: [StorageSegment] {
        [
            StorageSegment(id: "apps", color: Theme.accent, bytes: applicationsBytes),
            StorageSegment(id: "media", color: Theme.pink, bytes: mediaBytes),
            StorageSegment(id: "system", color: Theme.orange, bytes: systemBytes),
            StorageSegment(id: "free", color: Color(white: 0.3), bytes: freeBytes)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iPhone Storage")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Formatters.bytes(capacity.used, unit: unit)) of \(Formatters.bytes(capacity.total, unit: unit)) used")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryLabel)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatters.bytes(freeBytes, unit: unit))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                    Text("available")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryLabel)
                }
            }

            StorageBar(segments: segments, total: max(capacity.total, 1), height: 14)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ],
                spacing: 12
            ) {
                legendItem("Applications", color: Theme.accent, bytes: applicationsBytes)
                legendItem("Media", color: Theme.pink, bytes: mediaBytes)
                legendItem("System Data", color: Theme.orange, bytes: systemBytes)
                legendItem("Available", color: Color(white: 0.3), bytes: freeBytes)
            }
        }
        .cardStyle(padding: 18)
    }

    private func legendItem(_ title: String, color: Color, bytes: Int64) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryLabel)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(Formatters.bytes(bytes, unit: unit))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

struct StorageSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            StorageSummaryCard(
                capacity: DeviceCapacity(total: 256_000_000_000, available: 112_600_000_000),
                applicationsBytes: 78_400_000_000,
                unit: .automatic
            )
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }
}
