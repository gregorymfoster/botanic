import BotanicKit
import SwiftUI

/// The app's `Color(_ rgb:)` initializer lives in the main target's `AppTheme.swift`, which the
/// widget extension can't see. Mirror just what the Live Activity needs from the shared
/// `DuskPalette` so the activity matches Botanic's dusk identity.
extension Color {
    init(_ rgb: DuskPalette.RGB, opacity: Double = 1) {
        self.init(.sRGB, red: rgb.red / 255, green: rgb.green / 255, blue: rgb.blue / 255, opacity: opacity)
    }
}

/// The handful of Dusk colors used by the Live Activity, resolved from the shared palette.
enum DuskWidget {
    static let text = Color(DuskPalette.textPrimary)
    static let muted = Color(DuskPalette.textMuted, opacity: 0.85)
    static let peach = Color(DuskPalette.peach)
    static let pinkSoft = Color(DuskPalette.pinkSoft)
    static let lavender = Color(DuskPalette.lavender)
    static let surface = Color(DuskPalette.surfaceMid)
}
