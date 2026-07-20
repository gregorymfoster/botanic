import BotanicKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    var experiences: [Experience]
    /// Drives the push to Insights — bound so a launch arg can open it for screenshots.
    @Binding var autoOpenInsights: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive
    @State private var renamingExperience: Experience?
    @State private var renameDraft = ""
    @State private var deletingExperience: Experience?

    private var finished: [Experience] {
        experiences.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        List {
            Section {
                Text(countTitle)
                    .font(Dusk.serifItalic(16))
                    .foregroundStyle(Dusk.muted(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 0, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Button { autoOpenInsights = true } label: {
                    insightsCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.History.insightsCard)
                .listRowInsets(EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if finished.isEmpty {
                EmptyHistory()
                    .listRowInsets(EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(Array(finished.enumerated()), id: \.element.id) { index, exp in
                        NavigationLink(value: exp) {
                            ExperienceRow(experience: exp, emphasized: index == 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(AccessibilityID.History.experienceRowPrefix).\(exp.id.uuidString)")
                        .listRowInsets(EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deletingExperience = exp } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Dusk.danger)
                            .accessibilityIdentifier("\(AccessibilityID.History.deleteSwipePrefix).\(exp.id.uuidString)")

                            Button {
                                renameDraft = exp.title
                                renamingExperience = exp
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Color(r: 122, g: 111, b: 208))
                            .accessibilityIdentifier("\(AccessibilityID.History.renameSwipePrefix).\(exp.id.uuidString)")
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            ExperienceStore.live.delete(finished[index], in: modelContext)
                        }
                    }
                }

                Section {
                    Text("Titles are drafted on your device when an experience ends. Swipe to rename, or open one to edit anything.")
                        .font(Dusk.sans(11))
                        .foregroundStyle(Dusk.muted(0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowInsets(EdgeInsets(top: 10, leading: 22, bottom: 16, trailing: 22))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DuskBackground())
        .environment(\.editMode, $editMode)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !finished.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                    .foregroundStyle(Dusk.peach)
                    .accessibilityIdentifier(AccessibilityID.History.editToggle)
                }
            }
        }
        .navigationDestination(isPresented: $autoOpenInsights) {
            InsightsView(experiences: experiences)
        }
        .alert("Rename", isPresented: renameBinding) {
            TextField("Title", text: $renameDraft)
                .accessibilityIdentifier(AccessibilityID.History.renameField)
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityID.History.renameCancel)
            Button("Save") {
                if let exp = renamingExperience {
                    ExperienceStore.live.rename(exp, to: renameDraft, in: modelContext)
                }
                renamingExperience = nil
            }
            .accessibilityIdentifier(AccessibilityID.History.renameSave)
        }
        .confirmationDialog("Delete this experience?", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Delete experience", role: .destructive) {
                if let exp = deletingExperience {
                    ExperienceStore.live.delete(exp, in: modelContext)
                }
                deletingExperience = nil
            }
            .accessibilityIdentifier(AccessibilityID.History.deleteConfirm)
            Button("Keep", role: .cancel) { deletingExperience = nil }
                .accessibilityIdentifier(AccessibilityID.History.deleteKeep)
        } message: {
            Text("This removes its supplements, check-ins, and notes. This can't be undone.")
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renamingExperience != nil }, set: { if !$0 { renamingExperience = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deletingExperience != nil }, set: { if !$0 { deletingExperience = nil } })
    }

    private var countTitle: String {
        let n = finished.count
        return n == 1 ? "1 experience" : "\(n) experiences"
    }

    private var insightsCard: some View {
        HStack(spacing: 13) {
            Group {
                if sparkValues.count > 1 {
                    Sparkline(values: sparkValues)
                } else {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18)).foregroundStyle(Dusk.muted(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 46, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Patterns & insights")
                    .font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                Text(insightsSubtitle)
                    .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Dusk.muted(0.4))
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .warmGlassCard()
    }

    private var insightsSubtitle: String {
        finished.isEmpty
            ? "Trends, correlations & what helps — appear as you finish experiences"
            : "Trends, correlations & what helps — across \(finished.count) experiences"
    }

    /// Felt-valence trend across finished experiences (oldest → newest). Empty/single until there's
    /// enough history to draw a line — the card shows a placeholder glyph in that case.
    private var sparkValues: [Double] {
        finished.reversed().compactMap { $0.feltSummary?.valence }
    }
}

// MARK: - Rows

struct ExperienceRow: View {
    var experience: Experience
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RadialGradient(colors: swatchColors, center: .init(x: 0.38, y: 0.34),
                                     startRadius: 0, endRadius: 44))
                .frame(width: 42, height: 42)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1).blur(radius: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(experience.title)
                    .font(Dusk.serif(18)).foregroundStyle(Dusk.text)
                Text(subtitle)
                    .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5)).lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Dusk.muted(0.4))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .modifier(RowBackground(emphasized: emphasized))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(experience.title). \(subtitle)")
        .accessibilityHint("Opens this experience")
    }

    private var swatchColors: [Color] {
        let palettes: [[Color]] = [
            [Color(r: 253, g: 228, b: 214), Dusk.peach, Color(r: 217, g: 122, b: 90)],   // warm — peach
            [Color(r: 251, g: 220, b: 230), Dusk.pink, Color(r: 204, g: 111, b: 147)],   // mid — pink
            [Color(r: 230, g: 220, b: 251), Dusk.lavender, Color(r: 155, g: 134, b: 212)] // cool — lavender
        ]
        let idx: Int
        if let valence = experience.feltSummary?.valence {
            // Warmer for calmer / more-pleasant evenings, cooler for harder ones — descriptive, never
            // prescriptive, and stable across launches (unlike `Double.hashValue`, which Swift seeds
            // randomly per process, so the color used to change on every relaunch).
            idx = valence >= 0.66 ? 0 : (valence >= 0.4 ? 1 : 2)
        } else {
            // No reflection recorded — derive a stable color from the experience id rather than a
            // per-launch random hash.
            let bytes = experience.id.uuid
            idx = (Int(bytes.0) &+ Int(bytes.15)) % palettes.count
        }
        return palettes[idx]
    }

    private var subtitle: String {
        let count = experience.supplements.count
        let suppText = count == 1 ? "1 supplement" : "\(count) supplements"
        var parts = [BotanicFormat.shortDate(experience.startedAt), suppText,
                     experience.duration().botanicDuration]
        if let word = experience.feltWords.first {
            parts.append(word.lowercased())
        } else if let felt = experience.feltSummary {
            parts.append(felt.rawValue.lowercased())
        }
        return parts.joined(separator: " · ")
    }
}

private struct RowBackground: ViewModifier {
    var emphasized: Bool
    func body(content: Content) -> some View {
        if emphasized { content.warmGlassCard(cornerRadius: 20) }
        else { content.glassCard(fill: 0.05, cornerRadius: 20) }
    }
}

private struct EmptyHistory: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No experiences yet")
                .font(Dusk.serif(18)).foregroundStyle(Dusk.text)
            Text("End your first experience and it will appear here.")
                .font(Dusk.serifItalic(14)).foregroundStyle(Dusk.muted(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard(fill: 0.04, cornerRadius: 20)
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let pts = points(in: CGSize(width: w, height: h))
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Dusk.peach, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle().fill(Dusk.peach).frame(width: 5, height: 5).position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(0.0001, maxV - minV)
        return values.enumerated().map { i, v in
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat((v - minV) / range))
            return CGPoint(x: x, y: y)
        }
    }
}
