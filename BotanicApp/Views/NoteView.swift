import BotanicKit
import SwiftUI

/// The composer sheet for writing a freeform note onto an experience's timeline.
struct NoteView: View {
    var experience: Experience
    var onAdd: (String, JournalKind, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var composing: Bool

    var body: some View {
        SheetScaffold(
            title: "Note",
            leading: .cancel,
            trailingTitle: "Save",
            trailingEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onLeading: { dismiss() },
            onTrailing: send
        ) {
            VStack(spacing: 0) {
                Text("\(experience.title) · \(experience.duration().botanicDuration) in")
                    .font(Dusk.sans(12))
                    .foregroundStyle(Dusk.muted(0.45))
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                TextEditor(text: $text)
                    .font(Dusk.serifItalic(23))
                    .foregroundStyle(Dusk.text)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .lineSpacing(8)
                    .focused($composing)
                    .padding(.horizontal, 19)
                    .padding(.top, 12)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What's on your mind?")
                                .font(Dusk.serifItalic(23))
                                .foregroundStyle(Dusk.muted(0.35))
                                .padding(.horizontal, 24)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .onAppear { composing = true }

                bottomBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("If stuck: what does your body want you to know?")
                .font(Dusk.serifItalic(12))
                .foregroundStyle(Dusk.muted(0.5))

            Spacer(minLength: 8)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Dusk.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Dusk.accentGradient))
                    .shadow(color: Dusk.peach.opacity(0.6), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Save note")
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .glassCard(fill: 0.05, stroke: Dusk.glassStrokeStrong, cornerRadius: 22, highlighted: true)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Pass nil for the prompt: the fallback line above is just a hint shown in the UI, not
        // something the user is confirmed to be responding to, so it's more accurate not to claim
        // that provenance in the stored data.
        onAdd(trimmed, .freeform, nil)
        // Call dismiss() after onAdd so the caller's closure can stage any state it needs before
        // the sheet's dismiss transition fires.
        dismiss()
    }
}
