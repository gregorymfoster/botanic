import Foundation

/// The core "Dusk" colors as sRGB 0–255 component triples, kept UI-framework-free so the app theme
/// builds its SwiftUI `Color`s from one source and never drifts. Botanic's dark sibling of
/// Breathwork's `PaperPalette`.
public enum DuskPalette {
    public struct RGB: Sendable, Hashable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    // Surfaces (radial screen gradient, dark → darker)
    public static let surfaceTop = RGB(34, 22, 41)     // #221629
    public static let surfaceMid = RGB(21, 14, 28)     // #150e1c
    public static let surfaceDeep = RGB(14, 9, 19)     // #0e0913
    public static let surfaceLiveTop = RGB(42, 26, 51) // #2a1a33

    // Ink / text
    public static let textPrimary = RGB(248, 239, 244) // #f8eff4
    public static let textBright = RGB(243, 236, 242)  // #f3ecf2
    public static let textMuted = RGB(243, 221, 230)   // #f3dde6 (used at low opacity)

    // Accents
    public static let peach = RGB(244, 169, 138)       // #f4a98a
    public static let peachLight = RGB(249, 195, 168)  // #f9c3a8
    public static let pink = RGB(240, 160, 184)        // #f0a0b8
    public static let pinkSoft = RGB(240, 182, 194)    // #f0b6c2
    public static let lavender = RGB(201, 184, 245)    // #c9b8f5
    public static let mint = RGB(134, 239, 172)        // #86efac
    public static let mintSoft = RGB(167, 243, 208)    // #a7f3d0
    public static let danger = RGB(247, 179, 191)      // #f7b3bf
    public static let onAccent = RGB(58, 36, 56)       // #3a2438 — text on accent fills
}
