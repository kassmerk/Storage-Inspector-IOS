import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case storage
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .storage: return "Storage"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .storage: return "internaldrive.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .storage

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch tab {
            case .storage:
                StorageView()
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $tab)
        }
    }
}

/// Floating capsule tab bar, same shape as the one in Feather.
struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { item in
                Button {
                    guard selection != item else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == item ? Theme.accent : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(selection == item ? Theme.accent.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(white: 0.14))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 96)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(Theme.background)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(StorageStore())
            .preferredColorScheme(.dark)
    }
}
