import BotanicKit
import SwiftData
import SwiftUI

struct ExperienceDetailView: View {
    var experience: Experience
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleFieldFocused: Bool

    @State private var showingDeleteConfirm = false
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var subtitleDraft = ""
    @State private var isEditingSupplements = false
    @State private var supplementDrafts: [UUID: SupplementEditDraft] = [:]
    @State private var isEditingNote = false
    @State private var noteDraft = ""

    private var moments: [TimelineEntry] {
        ExperienceStore.timelineEntries(for: experience)
    }

    var body: some View {
        ZStack {
            DuskBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    titleBlock
                    statTrio
                    supplementsCard
                    noteCard
                    if !moments.isEmpty { momentsSection }
                    syncRow
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(BotanicFormat.shortDate(experience.startedAt, includeYear: true))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        beginEditingTitle()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    ShareLink(item: markdown) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
            }
        }
        .confirmationDialog("Delete this experience?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete experience", role: .destructive) {
                ExperienceStore.delete(experience, in: modelContext)
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This removes its supplements, check-ins, and notes. This can't be undone.")
        }
    }

    // MARK: - Title block

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(RadialGradient(colors: [Color(r: 253, g: 228, b: 214), Dusk.peach, Color(r: 217, g: 122, b: 90)],
                                     center: .init(x: 0.38, y: 0.34), startRadius: 0, endRadius: 52))
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                if isEditingTitle {
                    TextField("Title", text: $titleDraft)
                        .font(Dusk.serif(25, .medium)).foregroundStyle(Dusk.text)
                        .focused($titleFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(commitTitleEdit)
                        .accessibilityLabel("Experience title")
                } else {
                    Button {
                        beginEditingTitle()
                    } label: {
                        Text(experience.title)
                            .font(Dusk.serif(25, .medium)).foregroundStyle(Dusk.text)
                            .overlay(alignment: .bottom) {
                                dashedUnderline.offset(y: 3)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Title: \(experience.title)")
                    .accessibilityHint("Double tap to edit")
                }

                if isEditingTitle {
                    TextField("Add a line about this one…", text: $subtitleDraft, axis: .vertical)
                        .font(Dusk.serifItalic(15)).foregroundStyle(Dusk.muted(0.75))
                        .submitLabel(.done)
                        .onSubmit(commitTitleEdit)
                        .accessibilityLabel("Experience subtitle")
                } else {
                    Button {
                        beginEditingTitle()
                    } label: {
                        Text(experience.subtitle ?? "Add a line about this one…")
                            .font(Dusk.serifItalic(15))
                            .foregroundStyle(experience.subtitle == nil ? Dusk.muted(0.4) : Dusk.muted(0.75))
                    }
                    .buttonStyle(.plain)
                }

                if isEditingTitle {
                    HStack(spacing: 10) {
                        Button("Cancel") { isEditingTitle = false }
                            .font(Dusk.sans(12.5, .semibold)).foregroundStyle(Dusk.muted(0.6))
                        Button("Save", action: commitTitleEdit)
                            .font(Dusk.sans(12.5, .bold)).foregroundStyle(Dusk.peach)
                    }
                    .padding(.top, 2)
                } else {
                    Text(provenanceLabel)
                        .font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.45))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var dashedUnderline: some View {
        Rectangle()
            .fill(Dusk.peach.opacity(0.6))
            .frame(height: 1)
            .mask(
                HStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { _ in
                        Rectangle().frame(width: 4, height: 1)
                    }
                }
            )
    }

    private var provenanceLabel: String {
        switch experience.titleSource {
        case .ai: return "✦ Drafted on-device"
        case .user: return "Edited by you"
        }
    }

    private func beginEditingTitle() {
        titleDraft = experience.title
        subtitleDraft = experience.subtitle ?? ""
        isEditingTitle = true
        titleFieldFocused = true
    }

    private func commitTitleEdit() {
        ExperienceStore.updateSummary(experience, title: titleDraft, subtitle: subtitleDraft, in: modelContext)
        isEditingTitle = false
    }

    // MARK: - Stat trio

    private var statTrio: some View {
        HStack(spacing: 8) {
            StatTile(label: "Length", value: experience.duration().botanicDuration)
            StatTile(label: "Check-ins", value: "\(experience.checkIns.count)")
            StatTile(label: "Felt", value: feltValue)
        }
    }

    private var feltValue: String {
        if let word = experience.feltWords.first { return word }
        if let felt = experience.feltSummary { return felt.rawValue }
        return "—"
    }

    // MARK: - Supplements

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SUPPLEMENTS · \(experience.supplements.count)")
                    .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
                Spacer()
                Button(isEditingSupplements ? "Done" : "Edit") {
                    toggleSupplementEdit()
                }
                .font(Dusk.sans(11.5, .semibold))
                .foregroundStyle(Dusk.peach)
            }
            ForEach(Array(experience.supplements.sorted { $0.effectiveTime < $1.effectiveTime }.enumerated()),
                    id: \.element.id) { index, s in
                if isEditingSupplements {
                    editableSupplementRow(s, index: index)
                } else {
                    HStack(spacing: 10) {
                        Circle().fill(dotColor(index)).frame(width: 9, height: 9)
                        Text(s.name).font(Dusk.sans(14)).foregroundStyle(Dusk.muted(0.9))
                        Spacer()
                        Text(detail(for: s)).font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 18)
    }

    private func editableSupplementRow(_ s: SupplementEntry, index: Int) -> some View {
        let binding = Binding<SupplementEditDraft>(
            get: { supplementDrafts[s.id] ?? SupplementEditDraft(entry: s) },
            set: { supplementDrafts[s.id] = $0 }
        )
        return HStack(spacing: 10) {
            Circle().fill(dotColor(index)).frame(width: 9, height: 9)
            Text(s.name).font(Dusk.sans(14)).foregroundStyle(Dusk.muted(0.9))
            Spacer()
            TextField("Amount", text: binding.howTaking)
                .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.7))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onChange(of: binding.wrappedValue.howTaking) { _, _ in commitSupplementDraft(for: s) }
            DatePicker("", selection: binding.takenAt, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .font(Dusk.sans(12))
                .onChange(of: binding.wrappedValue.takenAt) { _, _ in commitSupplementDraft(for: s) }
        }
    }

    private func toggleSupplementEdit() {
        if isEditingSupplements {
            isEditingSupplements = false
            supplementDrafts.removeAll()
        } else {
            for s in experience.supplements {
                supplementDrafts[s.id] = SupplementEditDraft(entry: s)
            }
            isEditingSupplements = true
        }
    }

    private func commitSupplementDraft(for entry: SupplementEntry) {
        guard let draft = supplementDrafts[entry.id] else { return }
        ExperienceStore.updateSupplement(entry, howTaking: draft.howTaking, takenAt: draft.takenAt, in: modelContext)
    }

    private func dotColor(_ index: Int) -> Color {
        [Dusk.peach, Dusk.pink, Dusk.lavender][index % 3]
    }

    private func detail(for s: SupplementEntry) -> String {
        let when = s.takenAt ?? s.scheduledFor
        let timePart = when.map { BotanicFormat.clock($0) } ?? "scheduled"
        if let how = s.howTaking { return "\(how) · \(timePart)" }
        return timePart
    }

    // MARK: - Note to future me

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("NOTE TO FUTURE ME")
                .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft)
            if isEditingNote {
                TextField("What do you want to remember?", text: $noteDraft, axis: .vertical)
                    .font(Dusk.serifItalic(15.5)).foregroundStyle(Dusk.text).lineSpacing(2)
                    .lineLimit(2...6)
                    .submitLabel(.done)
                    .onSubmit(commitNoteEdit)
                HStack(spacing: 10) {
                    Button("Cancel") { isEditingNote = false }
                        .font(Dusk.sans(12.5, .semibold)).foregroundStyle(Dusk.muted(0.6))
                    Button("Save", action: commitNoteEdit)
                        .font(Dusk.sans(12.5, .bold)).foregroundStyle(Dusk.peach)
                }
            } else {
                Button {
                    noteDraft = experience.noteToFuture ?? ""
                    isEditingNote = true
                } label: {
                    Text(experience.noteToFuture.map { "“\($0)”" } ?? "Add a note to your future self…")
                        .font(Dusk.serifItalic(15.5))
                        .foregroundStyle(experience.noteToFuture == nil ? Dusk.muted(0.4) : Dusk.text)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmGlassCard(cornerRadius: 18)
    }

    private func commitNoteEdit() {
        ExperienceStore.updateNoteToFuture(experience, note: noteDraft, in: modelContext)
        isEditingNote = false
    }

    // MARK: - Moments

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOMENTS · \(moments.count)")
                .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            ForEach(Array(moments.enumerated()), id: \.element.id) { index, entry in
                TimelineRow(entry: entry, isLast: index == moments.count - 1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 18)
    }

    // MARK: - Sync row

    private var syncRow: some View {
        HStack(spacing: 11) {
            if let filename = experience.markdownFilename {
                Image(systemName: "checkmark.icloud").font(.system(size: 15)).foregroundStyle(Dusk.mint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Synced to folder").font(Dusk.sans(12.5)).foregroundStyle(Dusk.muted(0.8))
                    Text(filename)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Dusk.muted(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Image(systemName: "icloud.slash").font(.system(size: 15)).foregroundStyle(Dusk.muted(0.4))
                Text("Not mirrored yet — choose a folder in Settings")
                    .font(Dusk.sans(12.5)).foregroundStyle(Dusk.muted(0.5))
            }
            Spacer(minLength: 8)
            ShareLink(item: markdown) {
                Text("Share")
                    .font(Dusk.sans(13, .semibold))
                    .foregroundStyle(Dusk.peach)
            }
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .glassCard(fill: 0.05, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private var markdown: String {
        MarkdownExport.experience(experience)
    }
}

/// Value-type staging area for an in-progress supplement edit, so text-field/date-picker changes
/// don't write to SwiftData on every keystroke tick — committed via `ExperienceStore.updateSupplement`.
private struct SupplementEditDraft: Equatable {
    var howTaking: String
    var takenAt: Date

    init(entry: SupplementEntry) {
        self.howTaking = entry.howTaking ?? ""
        self.takenAt = entry.takenAt ?? entry.scheduledFor ?? Date()
    }
}
