import BotanicKit
import SwiftUI

// MARK: - Color helpers

extension Color {
    /// Build an sRGB color from 0–255 channel values.
    init(r: Double, g: Double, b: Double, o: Double = 1) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: o)
    }

    /// Builds a SwiftUI color from a shared `DuskPalette.RGB` (0–255) triple.
    init(_ rgb: DuskPalette.RGB, opacity: Double = 1) {
        self.init(r: rgb.red, g: rgb.green, b: rgb.blue, o: opacity)
    }
}

// MARK: - Dusk design system

/// The "Dusk" palette and typography: deep plum surfaces, soft peach/pink/lavender accents, and a
/// serif/sans pairing. Botanic is dark always — there is no light variant. (Sibling of Breathwork's
/// `Paper`.)
enum Dusk {
    // Surfaces
    static let surfaceTop = Color(DuskPalette.surfaceTop)
    static let surfaceMid = Color(DuskPalette.surfaceMid)
    static let surfaceDeep = Color(DuskPalette.surfaceDeep)
    static let surfaceLiveTop = Color(DuskPalette.surfaceLiveTop)

    // Ink / text
    static let text = Color(DuskPalette.textPrimary)
    static let textBright = Color(DuskPalette.textBright)
    /// Muted text — the warm off-white used throughout at various opacities.
    static func muted(_ opacity: Double) -> Color { Color(DuskPalette.textMuted, opacity: opacity) }

    // Accents
    static let peach = Color(DuskPalette.peach)
    static let peachLight = Color(DuskPalette.peachLight)
    static let pink = Color(DuskPalette.pink)
    static let pinkSoft = Color(DuskPalette.pinkSoft)
    static let lavender = Color(DuskPalette.lavender)
    static let mint = Color(DuskPalette.mint)
    static let mintSoft = Color(DuskPalette.mintSoft)
    static let danger = Color(DuskPalette.danger)
    static let onAccent = Color(DuskPalette.onAccent)

    static let accent = peach

    // Common gradients
    static let accentGradient = LinearGradient(
        colors: [peachLight, peach],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// The full-screen radial backdrop. `live` deepens to plum during an active experience.
    static func screenGradient(live: Bool) -> RadialGradient {
        RadialGradient(
            colors: [live ? surfaceLiveTop : surfaceTop, surfaceMid, surfaceDeep],
            center: .init(x: 0.5, y: live ? 0.18 : 0.28),
            startRadius: 0,
            endRadius: 720
        )
    }

    // Hairlines
    static let glassStroke = Color.white.opacity(0.11)
    static let glassStrokeStrong = Color.white.opacity(0.16)

    // MARK: Typography — Spectral (serif display) + Hanken Grotesk (sans body)

    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular) -> Font {
        Font.custom(weight.psName, size: size)
    }

    static func serifItalic(_ size: CGFloat, medium: Bool = false) -> Font {
        Font.custom(medium ? "Spectral-MediumItalic" : "Spectral-Italic", size: size)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("HankenGrotesk-Regular", size: size).weight(weight)
    }

    enum SerifWeight {
        case light, regular, medium, semibold
        var psName: String {
            switch self {
            case .light: return "Spectral-Light"
            case .regular: return "Spectral-Regular"
            case .medium: return "Spectral-Medium"
            case .semibold: return "Spectral-SemiBold"
            }
        }
    }
}

// MARK: - Glass surfaces

/// The signature frosted card: faint white fill over the dusk backdrop, hairline border, and a soft
/// top inset highlight so it reads as glass rather than a flat panel.
struct GlassCard: ViewModifier {
    var fill: Double = 0.055
    var stroke: Color = Dusk.glassStroke
    var cornerRadius: CGFloat = 18
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(fill))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.25)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                if highlighted {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.18), .clear],
                                           startPoint: .top, endPoint: .center),
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func glassCard(fill: Double = 0.055, stroke: Color = Dusk.glassStroke,
                   cornerRadius: CGFloat = 18, highlighted: Bool = false) -> some View {
        modifier(GlassCard(fill: fill, stroke: stroke, cornerRadius: cornerRadius, highlighted: highlighted))
    }

    /// A warm-tinted glass card (peach→lavender) for the emphasized "hero" surfaces.
    func warmGlassCard(cornerRadius: CGFloat = 20) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Dusk.peachLight.opacity(0.14), Dusk.lavender.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Dusk.peachLight.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Section label

/// Small uppercase tracked section heading, in peach/pink, used throughout the design.
struct SectionLabel: View {
    var title: String
    var color: Color = Dusk.pinkSoft.opacity(0.85)

    var body: some View {
        Text(title.uppercased())
            .font(Dusk.sans(11, .bold))
            .tracking(2)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

/// Solid peach primary action with a soft glow — the main call-to-action across the app.
struct DuskPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Dusk.sans(16, .bold))
            .foregroundStyle(Dusk.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Dusk.accentGradient)
                    .opacity(isEnabled ? 1 : 0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(color: Dusk.peach.opacity(isEnabled ? 0.5 : 0), radius: 22, x: 0, y: 14)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A faint glass secondary action.
struct DuskSoftButton: ButtonStyle {
    var height: CGFloat = 54
    var tint: Color = Dusk.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Dusk.sans(15, .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .glassCard(fill: 0.07, stroke: Dusk.glassStrokeStrong, cornerRadius: 18)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
