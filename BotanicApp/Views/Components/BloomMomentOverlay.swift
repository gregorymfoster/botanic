import BotanicKit
import SwiftUI

/// A transient "your save landed" moment shown ~1.5s after every successful save (supplement,
/// check-in, or note). Purely presentational and non-interactive — it never blocks input.
struct BloomEvent: Equatable {
    enum Kind: Equatable {
        case supplement(String)
        case checkIn(String)
        case note
    }
    var kind: Kind
    var savedAt: Date
    /// The live experience's title/elapsed, shown as a small pill when one is running.
    var liveTitle: String?
    var liveElapsed: String?

    /// The serif headline shown under the orb — "Magnesium glycinate", "Check-in · Settled", "Note".
    var title: String {
        switch kind {
        case .supplement(let name): return name
        case .checkIn(let word): return "Check-in · \(word)"
        case .note: return "Note"
        }
    }
}

/// A single falling petal's randomized-once appearance and motion, generated in `.onAppear` so
/// `body` never calls `.random` directly (SwiftUI re-evaluates body frequently).
private struct PetalConfig {
    var color: Color
    var size: CGFloat
    var xOffset: CGFloat
    var angle: Double
    var duration: Double
    var delay: Double
}

/// Full-screen confirmation moment: a breathing orb with a checkmark, ripples, and falling petals,
/// auto-dismissing after ~1.5s. Never intercepts touches.
struct BloomMomentOverlay: View {
    var event: BloomEvent
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var orbScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var ring1Visible = false
    @State private var ring2Visible = false
    @State private var petalsFallen = false
    @State private var petalConfigs: [PetalConfig] = []

    private static let orbColors: [Color] = [
        Color(r: 251, g: 213, b: 194),
        Color(r: 240, g: 160, b: 184),
        Color(r: 192, g: 132, b: 252)
    ]

    private static let petalPalette: [Color] = [Dusk.peach, Dusk.pink, Dusk.lavender]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            ZStack {
                if !reduceMotion {
                    ForEach(Array(petalConfigs.enumerated()), id: \.offset) { _, config in
                        petal(config)
                    }
                }

                if !reduceMotion {
                    ripple(visible: ring1Visible)
                    ripple(visible: ring2Visible)
                }

                orb
            }

            VStack(spacing: 14) {
                orbSpacer
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text(event.title)
                            .font(Dusk.serif(27, .medium))
                            .foregroundStyle(Dusk.text)
                            .multilineTextAlignment(.center)
                        Text("logged · \(BotanicFormat.clock(event.savedAt))")
                            .font(Dusk.sans(13))
                            .foregroundStyle(Dusk.muted(0.5))
                    }

                    if let liveTitle = event.liveTitle, let liveElapsed = event.liveElapsed {
                        livePill(title: liveTitle, elapsed: liveElapsed)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(event.title) logged")
            }
            .opacity(contentOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            petalConfigs = (0..<6).map { i in
                PetalConfig(
                    color: Self.petalPalette[i % Self.petalPalette.count],
                    size: CGFloat.random(in: 11...17),
                    xOffset: CGFloat.random(in: -70...70),
                    angle: Double.random(in: -60...60),
                    duration: Double.random(in: 4.2...5.8),
                    delay: Double(i) * 0.25
                )
            }

            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) {
                    orbScale = 1
                    contentOpacity = 1
                }
            } else {
                // A single spring naturally overshoots to ~1.08 before settling — simpler and just
                // as expressive as chaining a separate overshoot + settle animation pair.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                    orbScale = 1
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    contentOpacity = 1
                }
                withAnimation(.easeOut(duration: 2.6)) {
                    ring1Visible = true
                }
                withAnimation(.easeOut(duration: 2.6).delay(1.3)) {
                    ring2Visible = true
                }
                // Each petal's own `.animation(_:value:)` supplies its randomized duration/delay,
                // so flipping the flag here (without wrapping it) is enough to trigger every petal.
                petalsFallen = true
            }

            Task {
                try? await Task.sleep(for: .seconds(1.5))
                onFinished()
            }
        }
    }

    /// Reserves vertical space above the caption so the orb (drawn in the background ZStack) has
    /// room without the text stack overlapping it.
    private var orbSpacer: some View {
        Color.clear.frame(width: 118, height: 118)
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: Self.orbColors,
                        center: .init(x: 0.42, y: 0.38),
                        startRadius: 0, endRadius: 74
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1).blur(radius: 1)
                )
                .shadow(color: Color(r: 240, g: 160, b: 184, o: 0.45), radius: 28)
                .frame(width: 118, height: 118)

            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Dusk.onAccent)
        }
        .scaleEffect(orbScale)
        .accessibilityHidden(true)
    }

    private func ripple(visible: Bool) -> some View {
        Circle()
            .stroke(
                LinearGradient(colors: [Dusk.peach, Dusk.pink], startPoint: .top, endPoint: .bottom),
                lineWidth: 2
            )
            .frame(width: 118, height: 118)
            .scaleEffect(visible ? 2.1 : 0.55)
            .opacity(visible ? 0 : 0.6)
            .accessibilityHidden(true)
    }

    private func petal(_ config: PetalConfig) -> some View {
        Ellipse()
            .fill(config.color.opacity(0.7))
            .frame(width: config.size, height: config.size * 1.4)
            .offset(x: config.xOffset, y: petalsFallen ? 420 : -40)
            .rotationEffect(.degrees(petalsFallen ? config.angle : 0))
            .animation(.easeIn(duration: config.duration).delay(config.delay), value: petalsFallen)
            .accessibilityHidden(true)
    }

    private func livePill(title: String, elapsed: String) -> some View {
        HStack(spacing: 8) {
            PulseDot(size: 6)
            Text("\(title) · \(elapsed)")
                .font(Dusk.sans(12.5, .semibold))
                .foregroundStyle(Dusk.text)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .glassCard(fill: 0.07, cornerRadius: 20)
    }
}
