import BotanicKit
import SwiftUI

/// Two gentle steps: confirm ending, then a short reflection (one feeling word + a note to future
/// you). Confirming writes the experience to history.
struct EndExperienceView: View {
    var experience: Experience
    var onEnd: (ReflectionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .confirm
    @State private var reflection = ReflectionDraft()

    enum Phase { case confirm, reflect }

    var body: some View {
        ZStack {
            DuskBackground(live: true)
            switch phase {
            case .confirm: confirmCard
            case .reflect: reflectCard
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Confirm

    private var confirmCard: some View {
        VStack {
            VStack(spacing: 6) {
                SectionLabel(title: experience.title, color: Dusk.pinkSoft)
                Text(experience.duration().botanicDuration)
                    .font(Dusk.serif(40, .light))
                    .foregroundStyle(Dusk.muted(0.7))
                Text("still settling")
                    .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.42))
            }
            .padding(.top, 80)
            .opacity(0.6)

            Spacer()

            VStack(spacing: 0) {
                Text("End this experience?")
                    .font(Dusk.serif(25, .medium)).foregroundStyle(Dusk.text)
                    .padding(.bottom, 10)
                Text("Your timeline keeps running quietly in the background. You can step away and come back any time tonight — no need to close it out.")
                    .font(Dusk.serifItalic(16)).foregroundStyle(Dusk.muted(0.66))
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.bottom, 18)

                HStack(spacing: 11) {
                    Image(systemName: "clock").foregroundStyle(Dusk.peach)
                    Text("Ending writes tonight to your history and opens a short reflection.")
                        .font(Dusk.sans(13)).foregroundStyle(Dusk.muted(0.72))
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
                .glassCard(fill: 0.05, cornerRadius: 16)
                .padding(.bottom, 18)

                HStack(spacing: 11) {
                    Button("Not yet") { dismiss() }
                        .buttonStyle(DuskSoftButton())
                    Button("End & reflect") {
                        Haptics.tap()
                        reflection.feeling = experience.checkIns.last?.feeling ?? .settled
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .reflect }
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Dusk.peachLight.opacity(0.18), lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.bottom, 20)
        }
    }

    // MARK: Reflect

    private var reflectCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back") {
                    withAnimation { phase = .confirm }
                }
                .font(Dusk.sans(15)).foregroundStyle(Dusk.muted(0.6))
                Spacer()
                Text("Reflection").font(Dusk.serif(18)).foregroundStyle(Dusk.text)
                Spacer()
                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, 22).padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How did this\nexperience feel?")
                        .font(Dusk.serif(27, .medium)).foregroundStyle(Dusk.text)
                        .padding(.top, 8)

                    Text("ONE WORD")
                        .font(Dusk.sans(11, .bold)).tracking(1.8).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
                    FlowLayout(spacing: 9) {
                        ForEach(FeelingWord.allCases) { word in
                            TagChip(label: word.rawValue, selected: reflection.feeling == word) {
                                reflection.feeling = word
                            }
                        }
                    }

                    Text("NOTE TO FUTURE ME · OPTIONAL")
                        .font(Dusk.sans(11, .bold)).tracking(1.8).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
                        .padding(.top, 4)
                    TextField("", text: $reflection.noteToFuture,
                              prompt: Text("What do you want to remember about tonight?")
                        .foregroundColor(Dusk.muted(0.4)), axis: .vertical)
                        .font(Dusk.serifItalic(16)).foregroundStyle(Dusk.text)
                        .lineLimit(3...6)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .glassCard(fill: 0.05, cornerRadius: 18)

                    Button("End & save to history") {
                        Haptics.success()
                        onEnd(reflection)
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
    }
}
