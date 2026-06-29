import SwiftUI

// MARK: - Tab bar

enum AppTab: Hashable { case today, history, settings }

// MARK: - Live indicators

/// The pulsing peach dot used on the live pill and Today tab. A soft ring pings outward from the dot
/// to give a gentle "live" heartbeat; the dot itself breathes in opacity. Stills under Reduce Motion.
struct PulseDot: View {
    var size: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var ring = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Dusk.peach, lineWidth: 1.4)
                .frame(width: size, height: size)
                .scaleEffect(ring ? 2.7 : 1)
                .opacity(ring ? 0 : 0.55)
            Circle()
                .fill(Dusk.peach)
                .frame(width: size, height: size)
                .shadow(color: Dusk.peach, radius: pulse ? 3 : 7)
                .opacity(pulse ? 0.4 : 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeOut(duration: 2.6).repeatForever(autoreverses: false)) { ring = true }
        }
        .accessibilityHidden(true)
    }
}

/// "Experience · live" capsule. Breathes very gently to reinforce the live sense.
struct LivePill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        HStack(spacing: 8) {
            PulseDot(size: 8)
            Text("Experience · live")
                .font(Dusk.sans(12.5, .semibold))
                .foregroundStyle(Dusk.text)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .glassCard(fill: 0.07, cornerRadius: 20)
        .scaleEffect(breathe ? 1.015 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - Segmented two-way toggle

/// A native segmented control (e.g. Now / Schedule, Experiences / Supplements), themed to the Dusk
/// palette via `Dusk.applyControlAppearance()`. Keeps a string/index API so call sites stay simple.
struct SegmentedToggle: View {
    var options: [String]
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                Text(label).tag(index)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Tag chip

/// A selectable "what's present" chip.
struct TagChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(Dusk.sans(13.5, selected ? .semibold : .regular))
                .foregroundStyle(selected ? Dusk.onAccent : Dusk.muted(0.72))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Dusk.accentGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Dusk.glassStroke, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Slider

/// A custom 0…1 slider with a white knob. An optional gradient paints the whole track (valence); a
/// solid `fillGradient` paints only the filled portion (intensity, body load).
struct DuskSlider: View {
    @Binding var value: Double
    var trackGradient: LinearGradient?
    var fillGradient: LinearGradient?
    var knobSize: CGFloat = 24
    /// Step used by VoiceOver's increment/decrement adjustable action.
    var step: Double = 0.1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                    .overlay { if let trackGradient { Capsule().fill(trackGradient) } }
                    .frame(height: 10)

                if let fillGradient {
                    Capsule()
                        .fill(fillGradient)
                        .frame(width: max(10, clamped * width), height: 10)
                }

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .offset(x: clamped * (width - knobSize))
            }
            .frame(height: knobSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        value = min(max((g.location.x - knobSize / 2) / (width - knobSize), 0), 1)
                    }
            )
        }
        .frame(height: knobSize)
        .accessibilityElement()
        .accessibilityValue("\(Int((min(max(value, 0), 1)) * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + step)
            case .decrement: value = max(0, value - step)
            @unknown default: break
            }
        }
    }
}

// MARK: - Small stat tile

struct StatTile: View {
    var label: String
    var value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(label.uppercased())
                .font(Dusk.sans(9.5, .bold))
                .tracking(1.2)
                .foregroundStyle(Dusk.pinkSoft.opacity(0.8))
                .multilineTextAlignment(.center)
            Text(value)
                .font(Dusk.serif(19))
                .foregroundStyle(Dusk.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .glassCard(fill: 0.05, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
