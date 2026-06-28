import SwiftUI

// MARK: - Tab bar

enum AppTab: Hashable { case today, history, settings }

/// The floating frosted-glass tab bar. The Today tab shows a pulsing dot while an experience is live.
struct DuskTabBar: View {
    @Binding var selected: AppTab
    var live: Bool

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, "Today", systemImage: "circle.fill", showsLiveDot: live)
            tab(.history, "History", systemImage: "clock")
            tab(.settings, "Settings", systemImage: "gearshape")
        }
        .padding(.horizontal, 6)
        .frame(height: 66)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(Capsule(style: .continuous).strokeBorder(Dusk.glassStroke, lineWidth: 1))
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.14)).frame(height: 1).padding(.horizontal, 18)
        }
        .shadow(color: .black.opacity(0.4), radius: 28, y: 14)
        .padding(.horizontal, 18)
    }

    private func tab(_ tab: AppTab, _ title: String, systemImage: String, showsLiveDot: Bool = false) -> some View {
        let active = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: active ? .semibold : .regular))
                    if showsLiveDot {
                        PulseDot(size: 7)
                            .offset(x: 11, y: -10)
                    }
                }
                .frame(height: 24)
                Text(title)
                    .font(Dusk.sans(10, .semibold))
            }
            .foregroundStyle(active ? Dusk.peach : Dusk.muted(0.42))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Live indicators

/// The pulsing peach dot used on the live pill and Today tab.
struct PulseDot: View {
    var size: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Dusk.peach)
            .frame(width: size, height: size)
            .shadow(color: Dusk.peach, radius: pulse ? 3 : 7)
            .opacity(pulse ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

/// "Experience · live" capsule.
struct LivePill: View {
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
    }
}

// MARK: - Segmented two-way toggle

/// The pill segmented control (e.g. Now / Schedule, Experiences / Supplements).
struct SegmentedToggle: View {
    var options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                let active = selection == index
                Text(label)
                    .font(Dusk.sans(13.5, active ? .semibold : .regular))
                    .foregroundStyle(active ? Dusk.onAccent : Dusk.muted(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Dusk.accentGradient)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = index }
                    }
                    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(5)
        .glassCard(fill: 0.05, cornerRadius: 15)
    }
}

// MARK: - Tag chip

/// A selectable "what's present" chip.
struct TagChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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
