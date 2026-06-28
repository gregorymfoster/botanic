import BotanicKit
import SwiftUI

struct AddSupplementView: View {
    var hasLiveExperience: Bool
    var onSave: (SupplementDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SupplementDraft()
    @FocusState private var nameFocused: Bool

    var body: some View {
        SheetScaffold(
            title: "Add supplement",
            leading: .chevron,
            trailingTitle: "Save",
            trailingEnabled: draft.isValid,
            onLeading: { dismiss() },
            onTrailing: save
        ) {
            ScrollView {
                VStack(spacing: 12) {
                    FieldBlock(label: "What is it?", warm: true) {
                        TextField("", text: $draft.name, prompt: Text("Magnesium glycinate")
                            .foregroundColor(Dusk.muted(0.4)))
                            .font(Dusk.serif(24))
                            .foregroundStyle(Dusk.text)
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }

                    FieldBlock(label: "How you're taking it") {
                        TextField("", text: $draft.howTaking, prompt: Text("2 capsules with a tall glass of water.")
                            .foregroundColor(Dusk.muted(0.4)), axis: .vertical)
                            .font(Dusk.serifItalic(16))
                            .foregroundStyle(Dusk.muted(0.82))
                            .lineLimit(1...3)
                    }

                    FieldBlock(label: "Intention · optional") {
                        TextField("", text: $draft.intention, prompt: Text("A calmer evening and deeper sleep.")
                            .foregroundColor(Dusk.muted(0.4)), axis: .vertical)
                            .font(Dusk.serifItalic(16))
                            .foregroundStyle(Dusk.muted(0.82))
                            .lineLimit(1...3)
                    }

                    whenSection

                    if !hasLiveExperience {
                        startsNewHint
                    }

                    Spacer(minLength: 8)

                    Button(action: save) {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                            Text("Add supplement")
                        }
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                    .disabled(!draft.isValid)
                    .opacity(draft.isValid ? 1 : 0.5)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .onAppear { nameFocused = true }
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHEN")
                .font(Dusk.sans(11, .bold)).tracking(1.8)
                .foregroundStyle(Dusk.pinkSoft.opacity(0.85))
                .padding(.leading, 2)

            SegmentedToggle(options: ["Now", "Schedule for later"], selection: scheduleBinding)

            if draft.scheduleForLater {
                HStack {
                    Image(systemName: "clock").foregroundStyle(Dusk.lavender)
                    DatePicker("", selection: $draft.scheduledFor, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .tint(Dusk.peach)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .glassCard(fill: 0.05, cornerRadius: 16)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: "clock").font(.system(size: 16)).foregroundStyle(Dusk.peach)
                    Text("Starts now").font(Dusk.sans(14)).foregroundStyle(Dusk.muted(0.85))
                    Spacer()
                    Text(BotanicFormat.clock(Date()))
                        .font(Dusk.serif(15)).foregroundStyle(Dusk.muted(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .glassCard(fill: 0.05, cornerRadius: 16)
            }
        }
    }

    private var scheduleBinding: Binding<Int> {
        Binding(get: { draft.scheduleForLater ? 1 : 0 },
                set: { draft.scheduleForLater = ($0 == 1) })
    }

    private var startsNewHint: some View {
        HStack(spacing: 11) {
            Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(Dusk.pinkSoft)
            (Text("No experience running — saving this ")
                + Text("starts a new one.").foregroundColor(Dusk.text))
                .font(Dusk.sans(12.5))
                .foregroundStyle(Dusk.muted(0.7))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Dusk.pink.opacity(0.1), Dusk.lavender.opacity(0.05)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Dusk.pink.opacity(0.18), lineWidth: 1))
    }

    private func save() {
        guard draft.isValid else { return }
        onSave(draft)
    }
}
