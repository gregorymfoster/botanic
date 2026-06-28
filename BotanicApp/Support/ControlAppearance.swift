import BotanicKit
import SwiftUI
import UIKit

extension UIColor {
    /// Build a UIColor from a shared `DuskPalette.RGB` (0–255) triple — the UIKit twin of the
    /// `Color(_:)` initializer, so native controls draw from the same palette source.
    convenience init(_ rgb: DuskPalette.RGB, alpha: CGFloat = 1) {
        self.init(red: rgb.red / 255, green: rgb.green / 255, blue: rgb.blue / 255, alpha: alpha)
    }
}

extension Dusk {
    /// Themes the UIKit-backed controls SwiftUI wraps (currently the segmented `Picker`) to the Dusk
    /// palette. Called once at launch alongside font registration so native controls match the app's
    /// tone without each call site re-styling.
    static func applyControlAppearance() {
        applySegmentedAppearance()
        applyNavigationBarAppearance()
    }

    private static func applySegmentedAppearance() {
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(DuskPalette.peach)
        segmented.backgroundColor = UIColor(white: 1, alpha: 0.05)
        let font = UIFont(name: "HankenGrotesk-Regular", size: 13.5)
            ?? .systemFont(ofSize: 13.5, weight: .semibold)
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor(DuskPalette.textMuted, alpha: 0.62), .font: font],
            for: .normal
        )
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor(DuskPalette.onAccent), .font: font],
            for: .selected
        )
    }

    /// Transparent nav bar with Spectral serif titles, so the dusk backdrop shows through and the
    /// native large/inline titles keep the app's serif character.
    private static func applyNavigationBarAppearance() {
        let ink = UIColor(DuskPalette.textPrimary)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont(name: "Spectral-Regular", size: 18) ?? .systemFont(ofSize: 18)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont(name: "Spectral-Medium", size: 32) ?? .systemFont(ofSize: 32, weight: .medium)
        ]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = UIColor(DuskPalette.peach)
    }
}
