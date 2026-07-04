import BotanicKit
import SwiftUI

/// A violet tone distinct from `Dusk.lavender`, matching the valence slider's track gradient —
/// used to tint the intensity satellite chip/label so all three axes read as visually distinct.
private let violet = Color(r: 192, g: 132, b: 252)

struct CheckInView: View {
    var experience: Experience
    var onSave: (CheckInDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()
    @State private var usageCounts: [String: Int] = [:]

    /// The orb's blended word, derived from all three sliders via the shared pure engine.
    private var orbWord: String {
        CheckInWordEngine.orbWord(valence: draft.valence, intensity: draft.intensity, bodyLoad: draft.bodyLoad).rawValue
    }

    var body: some View {
        SheetScaffold(
            title: "Check-in",
            leading: .cancel,
            trailingTitle: "\(experience.duration().botanicDuration) in",
            trailingEnabled: false,
            onLeading: { dismiss() },
            onTrailing: {},
            leadingAccessibilityID: AccessibilityID.CheckIn.cancel
        ) {
            ScrollView {
                VStack(spacing: 16) {
                    Text("How does right\nnow feel?")
                        .font(Dusk.serif(27, .medium))
                        .foregroundStyle(Dusk.text)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    orbCluster
                        .padding(.vertical, 4)

                    Text("The orb reads your three sliders — its word shifts as you move them.")
                        .font(Dusk.sans(11.5))
                        .foregroundStyle(Dusk.muted(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    valenceSlider
                    scaleSlider(title: "Intensity", value: $draft.intensity,
                                word: CheckInWordEngine.intensityWord(draft.intensity),
                                wordColor: violet, colors: [Dusk.lavender, Dusk.pink])
                        .accessibilityIdentifier(AccessibilityID.CheckIn.intensitySlider)
                    scaleSlider(title: "Body load", value: $draft.bodyLoad,
                                word: CheckInWordEngine.bodyLoadWord(draft.bodyLoad),
                                wordColor: Dusk.lavender, colors: [Dusk.mint, Dusk.peach])
                        .accessibilityIdentifier(AccessibilityID.CheckIn.bodyLoadSlider)

                    presenceSection

                    FieldBlock(label: "Anything else? · optional") {
                        TextField("", text: $draft.note, prompt: Text("Anything you want to remember about this moment.")
                            .foregroundColor(Dusk.muted(0.4)), axis: .vertical)
                            .font(Dusk.serifItalic(16))
                            .foregroundStyle(Dusk.muted(0.82))
                            .lineLimit(1...3)
                            .accessibilityIdentifier(AccessibilityID.CheckIn.noteField)
                    }

                    Spacer(minLength: 8)

                    Button("Save check-in") {
                        onSave(commit())
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                    .accessibilityIdentifier(AccessibilityID.CheckIn.save)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear { usageCounts = TagUsageStore.counts() }
    }

    // MARK: - Orb + satellite chips

    /// The orb with three small "satellite" word chips floating near its edge, one per slider axis.
    /// Positioned via fixed offsets tuned to the orb's 188pt size rather than a floating-layout
    /// system — simplest way to get a "floating around the orb" read inside a ScrollView.
    private var orbCluster: some View {
        ZStack {
            CheckInOrb(word: orbWord)
                // The word crossfades via `.contentTransition(.opacity)` inside CheckInOrb itself;
                // wrapping the value change in an explicit animation ensures the transition actually
                // animates rather than relying on an ambient transaction from the slider drag.
                .animation(.easeInOut(duration: 0.2), value: orbWord)

            // Offsets keep every chip fully outside the orb's 94pt radius so the words stay
            // legible against the background rather than getting swallowed by the orb's glow.
            satelliteChip(CheckInWordEngine.valenceWord(draft.valence), color: Dusk.peach)
                .offset(x: -112, y: -78)
            satelliteChip(CheckInWordEngine.intensityWord(draft.intensity), color: violet)
                .offset(x: 112, y: -72)
            satelliteChip(CheckInWordEngine.bodyLoadWord(draft.bodyLoad), color: Dusk.lavender)
                .offset(x: 58, y: 108)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func satelliteChip(_ word: String, color: Color) -> some View {
        Text(word)
            .font(Dusk.serifItalic(13))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(color.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: word)
            // Decorative reinforcement of values already exposed via each slider's own
            // accessibility label — hidden here to avoid VoiceOver reading the same value twice.
            .accessibilityHidden(true)
    }

    // MARK: - Sliders

    private var valenceSlider: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Unpleasant")
                Spacer()
                Text(CheckInWordEngine.valenceWord(draft.valence))
                    .font(Dusk.serifItalic(13))
                    .foregroundStyle(Dusk.peach)
            }
            .font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.5))

            DuskSlider(
                value: $draft.valence,
                trackGradient: LinearGradient(
                    colors: [Color(r: 107, g: 85, b: 112), violet, Dusk.peach],
                    startPoint: .leading, endPoint: .trailing),
                knobSize: 26
            )
            .accessibilityLabel("Pleasantness, from unpleasant to pleasant")
            .accessibilityIdentifier(AccessibilityID.CheckIn.valenceSlider)
        }
    }

    private func scaleSlider(title: String, value: Binding<Double>, word: String,
                             wordColor: Color, colors: [Color]) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text(title)
                Spacer()
                Text(word)
                    .font(Dusk.serifItalic(13))
                    .foregroundStyle(wordColor)
            }
            .font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.5))

            DuskSlider(
                value: value,
                fillGradient: LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                knobSize: 22
            )
            .accessibilityLabel(title)
        }
    }

    // MARK: - Presence

    private var presenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT'S PRESENT?")
                .font(Dusk.sans(11, .bold)).tracking(1.8)
                .foregroundStyle(Dusk.pinkSoft.opacity(0.85))

            ForEach(PresenceGroup.allCases, id: \.self) { group in
                VStack(alignment: .leading, spacing: 9) {
                    Text(group.label)
                        .font(Dusk.sans(10.5, .bold))
                        .tracking(1.4)
                        .foregroundStyle(groupColor(group).opacity(0.85))

                    FlowLayout(spacing: 9) {
                        ForEach(CheckInWordEngine.orderedTags(group.words, usageCounts: usageCounts), id: \.self) { tag in
                            TagChip(label: tag, selected: draft.tags.contains(tag)) {
                                if draft.tags.contains(tag) { draft.tags.remove(tag) } else { draft.tags.insert(tag) }
                            }
                            .accessibilityIdentifier("\(AccessibilityID.CheckIn.tagChipPrefix).\(tag)")
                        }
                    }
                }
            }

            Text("Words you use often float to the front of each row.")
                .font(Dusk.sans(11.5))
                .foregroundStyle(Dusk.muted(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupColor(_ group: PresenceGroup) -> Color {
        switch group {
        case .body: return Dusk.peach
        case .mind: return Dusk.lavender
        case .heart: return Dusk.pink
        }
    }

    // MARK: - Commit

    private func commit() -> CheckInDraft {
        var d = draft
        d.feeling = CheckInWordEngine.orbWord(valence: draft.valence, intensity: draft.intensity, bodyLoad: draft.bodyLoad)
        TagUsageStore.increment(Array(draft.tags))
        return d
    }
}
