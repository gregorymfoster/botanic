import BotanicKit
import SwiftUI

struct CheckInView: View {
    var experience: Experience
    var onSave: (CheckInDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()

    private let presenceTags = Array(PresenceTag.all.prefix(8))

    /// The orb word follows the valence slider so the sphere responds as you move it.
    private var feeling: FeelingWord {
        FeelingWord.allCases.min {
            abs($0.valence - draft.valence) < abs($1.valence - draft.valence)
        } ?? .settled
    }

    var body: some View {
        SheetScaffold(
            title: "Check-in",
            leading: .cancel,
            trailingTitle: "\(experience.duration().botanicDuration) in",
            trailingEnabled: false,
            onLeading: { dismiss() },
            onTrailing: {}
        ) {
            ScrollView {
                VStack(spacing: 16) {
                    Text("How does right\nnow feel?")
                        .font(Dusk.serif(27, .medium))
                        .foregroundStyle(Dusk.text)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    CheckInOrb(word: feeling.rawValue)
                        .padding(.vertical, 4)

                    valenceSlider
                    scaleSlider(title: "Intensity", value: $draft.intensity,
                                word: word(draft.intensity, ["Gentle", "Steady", "Strong"]),
                                colors: [Dusk.lavender, Dusk.pink])
                    scaleSlider(title: "Body load", value: $draft.bodyLoad,
                                word: word(draft.bodyLoad, ["Light", "Moderate", "Heavy"]),
                                colors: [Dusk.mint, Dusk.peach])

                    presenceSection

                    Spacer(minLength: 8)

                    Button("Save check-in") {
                        Haptics.success()
                        onSave(commit())
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var valenceSlider: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Unpleasant"); Spacer(); Text("Pleasant")
            }
            .font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.5))

            DuskSlider(
                value: $draft.valence,
                trackGradient: LinearGradient(
                    colors: [Color(r: 107, g: 85, b: 112), Color(r: 192, g: 132, b: 252), Dusk.peach],
                    startPoint: .leading, endPoint: .trailing),
                knobSize: 26
            )
            .accessibilityLabel("Pleasantness, from unpleasant to pleasant")
        }
    }

    private func scaleSlider(title: String, value: Binding<Double>, word: String, colors: [Color]) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text(title); Spacer(); Text(word).foregroundStyle(Dusk.muted(0.72))
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

    private var presenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT'S PRESENT?")
                .font(Dusk.sans(11, .bold)).tracking(1.8)
                .foregroundStyle(Dusk.pinkSoft.opacity(0.85))

            FlowLayout(spacing: 9) {
                ForEach(presenceTags, id: \.self) { tag in
                    TagChip(label: tag, selected: draft.tags.contains(tag)) {
                        if draft.tags.contains(tag) { draft.tags.remove(tag) } else { draft.tags.insert(tag) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func word(_ value: Double, _ words: [String]) -> String {
        let index = min(Int(value * Double(words.count)), words.count - 1)
        return words[max(0, index)]
    }

    private func commit() -> CheckInDraft {
        var d = draft
        d.feeling = feeling
        return d
    }
}
