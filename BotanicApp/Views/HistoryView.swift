import BotanicKit
import SwiftUI

struct HistoryView: View {
    var experiences: [Experience]
    /// Drives the push to Insights — bound so a launch arg can open it for screenshots.
    @Binding var autoOpenInsights: Bool
    @State private var tab = 0

    private var finished: [Experience] {
        experiences.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(title: "History", color: Dusk.pinkSoft)
                    Text(countTitle)
                        .font(Dusk.serif(30, .medium))
                        .foregroundStyle(Dusk.text)
                }
                .padding(.top, 4)

                Button { autoOpenInsights = true } label: {
                    insightsCard
                }
                .buttonStyle(.plain)

                SegmentedToggle(options: ["Experiences", "Supplements"], selection: $tab)

                if tab == 0 {
                    experiencesList
                } else {
                    supplementsList
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(isPresented: $autoOpenInsights) {
            InsightsView(experiences: experiences)
        }
    }

    private var countTitle: String {
        let n = finished.count
        return n == 1 ? "1 experience" : "\(n) experiences"
    }

    private var insightsCard: some View {
        HStack(spacing: 13) {
            Sparkline(values: sparkValues)
                .frame(width: 46, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Patterns & insights")
                    .font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                Text("Trends, correlations & what helps — across \(finished.count) experiences")
                    .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Dusk.muted(0.4))
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .warmGlassCard()
    }

    private var sparkValues: [Double] {
        let vals = finished.reversed().compactMap { $0.feltSummary?.valence }
        return vals.isEmpty ? [0.4, 0.55, 0.5, 0.7, 0.65, 0.85] : vals
    }

    private var experiencesList: some View {
        VStack(spacing: 11) {
            if finished.isEmpty {
                EmptyHistory()
            } else {
                ForEach(Array(finished.enumerated()), id: \.element.id) { index, exp in
                    NavigationLink(value: exp) {
                        ExperienceRow(experience: exp, emphasized: index == 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var supplementsList: some View {
        VStack(spacing: 11) {
            let counts = supplementCounts
            if counts.isEmpty {
                EmptyHistory()
            } else {
                ForEach(Array(counts.enumerated()), id: \.element.label) { index, item in
                    HStack(spacing: 13) {
                        SupplementSwatch(colorIndex: index, size: 44, checked: false)
                        Text(item.label).font(Dusk.serif(17)).foregroundStyle(Dusk.text)
                        Spacer()
                        Text(item.count == 1 ? "1 time" : "\(item.count) times")
                            .font(Dusk.sans(12.5)).foregroundStyle(Dusk.muted(0.5))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .glassCard(fill: 0.05, cornerRadius: 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.label), logged \(item.count == 1 ? "1 time" : "\(item.count) times")")
                }
            }
        }
    }

    private var supplementCounts: [LabeledCount] {
        let snapshots = ExperienceStore.snapshots(from: finished)
        return InsightsEngine.summary(for: snapshots).topSupplements
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
                .frame(width: 44, height: 44)
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
            [Color(r: 253, g: 228, b: 214), Dusk.peach, Color(r: 217, g: 122, b: 90)],
            [Color(r: 251, g: 220, b: 230), Dusk.pink, Color(r: 204, g: 111, b: 147)],
            [Color(r: 230, g: 220, b: 251), Dusk.lavender, Color(r: 155, g: 134, b: 212)]
        ]
        let idx = abs(experience.feltSummary?.valence.hashValue ?? experience.title.hashValue) % palettes.count
        return palettes[idx]
    }

    private var subtitle: String {
        let count = experience.supplements.count
        let suppText = count == 1 ? "1 supplement" : "\(count) supplements"
        var parts = [BotanicFormat.shortDate(experience.startedAt), suppText,
                     experience.duration().botanicDuration]
        if let felt = experience.feltSummary { parts.append(felt.rawValue.lowercased()) }
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
