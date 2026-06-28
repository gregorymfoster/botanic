import SwiftUI

/// The idle "bloom": five overlapping soft petals slowly rotating around a breathing core. Shown on
/// the empty Today screen. Motion stills under Reduce Motion (the static bloom still reads well).
struct BloomOrb: View {
    var size: CGFloat = 148
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var breathe = false

    private let petalColors: [Color] = [
        Color(r: 244, g: 169, b: 138, o: 0.5),
        Color(r: 240, g: 160, b: 184, o: 0.5),
        Color(r: 201, g: 184, b: 245, o: 0.46),
        Color(r: 244, g: 169, b: 138, o: 0.48),
        Color(r: 240, g: 160, b: 184, o: 0.46)
    ]

    var body: some View {
        ZStack {
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    petal(petalColors[i])
                        .rotationEffect(.degrees(Double(i) * 72))
                }
            }
            .rotationEffect(.degrees(spin ? 360 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(r: 255, g: 247, b: 240, o: 0.9),
                                 Color(r: 246, g: 205, b: 180, o: 0.4), .clear],
                        center: .center, startRadius: 0, endRadius: 32
                    )
                )
                .frame(width: 62, height: 62)
                .blur(radius: 2)
                .scaleEffect(breathe ? 1.05 : 1)
                .opacity(breathe ? 1 : 0.94)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 110).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private func petal(_ color: Color) -> some View {
        Ellipse()
            .fill(
                RadialGradient(colors: [color, .clear], center: .init(x: 0.5, y: 0.28),
                               startRadius: 0, endRadius: 54)
            )
            .frame(width: 74, height: 108)
            .blur(radius: 3)
            .blendMode(.screen)
            .offset(y: -54)
    }
}

/// The breathing feeling sphere shown on the check-in screen, with the chosen feeling word centered.
struct CheckInOrb: View {
    var word: String
    var size: CGFloat = 188
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(r: 251, g: 213, b: 194),
                                 Color(r: 240, g: 160, b: 184),
                                 Color(r: 192, g: 132, b: 252)],
                        center: .init(x: 0.42, y: 0.38),
                        startRadius: 0, endRadius: size * 0.62
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1).blur(radius: 1)
                )
                .shadow(color: Color(r: 240, g: 160, b: 184, o: 0.45), radius: 28)
                .scaleEffect(breathe ? 1.04 : 0.98)

            Text(word)
                .font(Dusk.serifItalic(28))
                .foregroundStyle(Dusk.onAccent)
                .shadow(color: .white.opacity(0.4), radius: 8)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current feeling: \(word)")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// The small jewel-like swatch that fronts a supplement, colored by its `colorIndex`.
struct SupplementSwatch: View {
    var colorIndex: Int
    var size: CGFloat = 42
    var checked: Bool = true

    private static let gradients: [[Color]] = [
        [Color(r: 253, g: 228, b: 214), Color(r: 244, g: 169, b: 138), Color(r: 217, g: 122, b: 90)],
        [Color(r: 251, g: 220, b: 230), Color(r: 240, g: 160, b: 184), Color(r: 204, g: 111, b: 147)],
        [Color(r: 230, g: 220, b: 251), Color(r: 201, g: 184, b: 245), Color(r: 155, g: 134, b: 212)]
    ]

    var body: some View {
        let colors = Self.gradients[abs(colorIndex) % Self.gradients.count]
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(
                RadialGradient(colors: colors, center: .init(x: 0.38, y: 0.34),
                               startRadius: 0, endRadius: size)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    .blur(radius: 0.5)
            )
            .frame(width: size, height: size)
            .overlay {
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }
}
