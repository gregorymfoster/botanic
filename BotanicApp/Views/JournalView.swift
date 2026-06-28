import BotanicKit
import SwiftUI

struct JournalView: View {
    var experience: Experience
    var onAdd: (String, JournalKind, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var promptIndex = 0
    @FocusState private var composing: Bool

    private var prompt: String { JournalPrompt.at(promptIndex) }

    var body: some View {
        SheetScaffold(
            title: "Journal",
            leading: .chevron,
            onLeading: { dismiss() }
        ) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(title: "\(experience.title) · live", color: Dusk.pinkSoft)
                            .padding(.bottom, 14)

                        if timeline.isEmpty {
                            Text("Your timeline fills in as you log supplements, check in, and write.")
                                .font(Dusk.serifItalic(15))
                                .foregroundStyle(Dusk.muted(0.5))
                                .padding(.vertical, 12)
                        } else {
                            ForEach(Array(timeline.enumerated()), id: \.element.id) { index, entry in
                                TimelineRow(entry: entry, isLast: index == timeline.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }

                composer
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
    }

    // MARK: Timeline

    private var timeline: [TimelineEntry] {
        ExperienceStore.timelineEntries(for: experience)
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(Dusk.peach)
                Text("FREEFORM · JUST WRITE")
                    .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft)
            }

            TextField("", text: $text, prompt: Text(prompt).foregroundColor(Dusk.muted(0.4)), axis: .vertical)
                .font(Dusk.serifItalic(16.5))
                .foregroundStyle(Dusk.text)
                .lineLimit(2...5)
                .focused($composing)

            HStack {
                Button {
                    withAnimation { promptIndex += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12))
                        Text("New prompt").font(Dusk.sans(12, .semibold))
                    }
                    .foregroundStyle(Dusk.peach)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Dusk.peach.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Dusk.peach.opacity(0.26), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Dusk.onAccent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Dusk.accentGradient))
                        .shadow(color: Dusk.peach.opacity(0.6), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .glassCard(fill: 0.05, stroke: Dusk.glassStrokeStrong, cornerRadius: 22, highlighted: true)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, .freeform, prompt)
        text = ""
        promptIndex += 1
        composing = false
    }
}
