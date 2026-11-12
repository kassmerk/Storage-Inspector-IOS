import SwiftUI
import UIKit

/// Thin wrapper around `UIApplication.setAlternateIconName(_:)`.
///
/// The alternate icons only exist when the bundle contains the extra `Icon*.png` files and the
/// matching `CFBundleAlternateIcons` entry in `Info.plist`; the packaging script adds both.
/// When they are missing (e.g. a run from the frozen project file without the packaging step)
/// `isSupported` stays `false` and the Settings card explains why instead of failing silently.
///
/// The class is deliberately *not* main-actor isolated so it can be created in a SwiftUI
/// property initializer; every `UIApplication` touch happens inside a `@MainActor` closure.
final class AppIconManager: ObservableObject {
    @Published private(set) var current: AppIconStyle = .orange
    @Published private(set) var isSupported = true
    @Published private(set) var isApplying = false
    @Published var errorMessage: String?

    init() {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    /// Re-reads what iOS currently has stored. `isSupported` is `false` when the bundle contains
    /// no `CFBundleAlternateIcons`, i.e. there is nothing to switch to.
    @MainActor
    func refresh() {
        let app = UIApplication.shared
        isSupported = app.supportsAlternateIcons
        current = AppIconStyle.style(forAlternateName: app.alternateIconName)
    }

    func apply(_ style: AppIconStyle) {
        guard style != current, !isApplying else { return }

        guard isSupported else {
            errorMessage = "This build does not include the extra icon files, so the icon cannot be changed here."
            return
        }

        isApplying = true
        Task { @MainActor in
            UIApplication.shared.setAlternateIconName(style.alternateName) { error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isApplying = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.current = style
                    }
                }
            }
        }
    }
}
