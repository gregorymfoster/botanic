import BotanicKit
import SwiftData
import SwiftUI

struct ExperienceDetailView: View {
    var experience: Experience
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirm = false

    private var moments: [TimelineEntry] {
        ExperienceStore.timelineEntries(for: experience)
    }

    var body: some View {
        ZStack {
            DuskBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    titleBlock
                    contextStrip
                    supplementsCard
                    if let note = experience.noteToFuture { noteCard(note) }
                    if !moments.isEmpty { momentsSection }
                    privacyRow
                    exportButton
                    deleteButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(BotanicFormat.shortDate(experience.startedAt, includeYear: true))
        .navigationBarTitleDisplayMode(.inline)
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

    private var titleBlock: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RadialGradient(colors: [Color(r: 253, g: 228, b: 214), Dusk.peach, Color(r: 217, g: 122, b: 90)],
                                     center: .init(x: 0.38, y: 0.34), startRadius: 0, endRadius: 52))
                .frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(experience.title).font(Dusk.serif(25, .medium)).foregroundStyle(Dusk.text)
                Text(headerSubtitle).font(Dusk.sans(12.5)).foregroundStyle(Dusk.muted(0.52))
            }
            Spacer()
        }
    }

    private var headerSubtitle: String {
        var parts = ["Experience", experience.duration().botanicDuration]
        if let felt = experience.feltSummary { parts.append("felt \(felt.rawValue.lowercased())") }
        return parts.joined(separator: " · ")
    }

    private var contextStrip: some View {
        HStack(spacing: 8) {
            contextTile("mappin.and.ellipse", Dusk.pinkSoft,
                        experience.locationContext ?? "—", name: "Location",
                        spoken: experience.locationContext ?? "not set")
            contextTile("waveform.path", Dusk.lavender,
                        experience.feltSummary?.rawValue ?? "—", name: "Felt",
                        spoken: experience.feltSummary?.rawValue ?? "not recorded")
            contextTile("checkmark.circle", Dusk.peach,
                        "\(experience.checkIns.count) check-ins", name: "Check-ins",
                        spoken: "\(experience.checkIns.count)")
        }
    }

    private func contextTile(_ icon: String, _ tint: Color, _ label: String,
                             name: String, spoken: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(label).font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.55)).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11)
        .glassCard(fill: 0.05, cornerRadius: 15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(spoken)")
    }

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUPPLEMENTS · \(experience.supplements.count)")
                .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            ForEach(Array(experience.supplements.sorted { $0.effectiveTime < $1.effectiveTime }.enumerated()),
                    id: \.element.id) { index, s in
                HStack(spacing: 10) {
                    Circle().fill(dotColor(index)).frame(width: 9, height: 9)
                    Text(s.name).font(Dusk.sans(14)).foregroundStyle(Dusk.muted(0.9))
                    Spacer()
                    Text(detail(for: s)).font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 18)
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

    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("NOTE TO FUTURE ME")
                .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft)
            Text("“\(note)”")
                .font(Dusk.serifItalic(15.5)).foregroundStyle(Dusk.text).lineSpacing(2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmGlassCard(cornerRadius: 18)
    }

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

    private var privacyRow: some View {
        HStack(spacing: 11) {
            Image(systemName: "lock").font(.system(size: 15)).foregroundStyle(Dusk.mint)
            Text("Stored on device").font(Dusk.sans(12.5)).foregroundStyle(Dusk.muted(0.8))
            Spacer()
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .glassCard(fill: 0.05, cornerRadius: 16)
    }

    private var exportButton: some View {
        ShareLink(item: markdown) {
            HStack(spacing: 9) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
                Text("Export as Markdown")
            }
            .font(Dusk.sans(14.5, .bold))
            .foregroundStyle(Dusk.onAccent)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Dusk.accentGradient))
            .shadow(color: Dusk.peach.opacity(0.5), radius: 18, y: 10)
        }
        .accessibilityLabel("Export as Markdown")
        .accessibilityHint("Shares this experience as a Markdown file")
    }

    private var deleteButton: some View {
        Button(role: .destructive) { showingDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash").font(.system(size: 14))
                Text("Delete experience").font(Dusk.sans(13.5, .semibold))
            }
            .foregroundStyle(Dusk.danger.opacity(0.9))
            .frame(maxWidth: .infinity).frame(height: 46)
            .glassCard(fill: 0.03, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityHint("Permanently removes this experience")
    }

    private var markdown: String {
        MarkdownExport.experience(experience)
    }
}
