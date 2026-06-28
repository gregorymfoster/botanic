import SwiftUI

/// The full-bleed dusk backdrop: a deep radial plum gradient with two slow-drifting, heavily-blurred
/// color orbs. Used behind every screen. Drift stills under Reduce Motion.
struct DuskBackground: View {
    var live: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Dusk.screenGradient(live: live)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack {
                    orb(Dusk.peach, size: 340)
                        .position(x: w * 0.18, y: 120)
                        .offset(x: drift ? 26 : -8, y: drift ? 30 : -6)
                    orb(Dusk.lavender, size: 320)
                        .position(x: w * 0.86, y: 460)
                        .offset(x: drift ? -28 : 10, y: drift ? -24 : 8)
                }
                .opacity(0.32)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func orb(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(colors: [color, .clear], center: .center,
                               startRadius: 0, endRadius: size * 0.5)
            )
            .frame(width: size, height: size)
            .blur(radius: 60)
    }
}
