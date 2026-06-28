import BotanicKit
import Charts
import SwiftUI

struct InsightsView: View {
    var experiences: [Experience]
    @Environment(\.dismiss) private var dismiss

    private var summary: InsightsSummary {
        InsightsEngine.summary(for: ExperienceStore.snapshots(from: experiences.filter { $0.endedAt != nil }))
    }

    var body: some View {
        ZStack {
            DuskBackground()
            VStack(spacing: 0) {
                header.padding(.horizontal, 22).padding(.top, 8)
                if summary.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack {
            Text("Insights").font(Dusk.serif(18)).foregroundStyle(Dusk.text)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Dusk.text).frame(width: 38, height: 38).glassCard(fill: 0.07, cornerRadius: 19)
                }
                Spacer()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            BloomOrb(size: 120)
            Text("Patterns appear with time")
                .font(Dusk.serif(20, .medium)).foregroundStyle(Dusk.text)
            Text("End a few experiences and Botanic will quietly show you what your evenings have in common.")
                .font(Dusk.serifItalic(15)).foregroundStyle(Dusk.muted(0.55))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                intro
                feltTrendCard
                statTiles
                SectionLabel(title: "What seems to help").padding(.top, 2)
                if let help = summary.topHelp { helpCard(help) }
                if !summary.locationCounts.isEmpty { locationCard }
                if !summary.topSupplements.isEmpty { barsCard(title: "Most-logged supplements", items: summary.topSupplements) }
                if !summary.topWords.isEmpty { barsCard(title: "Words you reach for", items: summary.topWords, serif: true) }
                disclaimer
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(title: "Patterns", color: Dusk.pinkSoft)
            Text("What your evenings\nare quietly showing")
                .font(Dusk.serif(27, .medium)).foregroundStyle(Dusk.text)
            Text("Across \(summary.experienceCount) experiences · your own notes")
                .font(Dusk.serifItalic(14)).foregroundStyle(Dusk.muted(0.5))
        }
    }

    private var feltTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HOW THEY FELT").font(Dusk.sans(11, .bold)).tracking(1.4).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
                Spacer()
                Text(summary.trendingCalmer ? "trending calmer" : "steady over time")
                    .font(Dusk.sans(11)).foregroundStyle(Dusk.muted(0.45))
            }
            Chart(summary.feltTrend) { point in
                AreaMark(x: .value("Date", point.date), y: .value("Felt", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Dusk.peach.opacity(0.42), Dusk.lavender.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date), y: .value("Felt", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Dusk.peachLight)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Dusk.muted(0.4))
                        .font(Dusk.sans(10))
                }
            }
            .frame(height: 132)
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .warmGlassCard()
    }

    private var statTiles: some View {
        HStack(spacing: 9) {
            StatTile(label: "Avg length", value: summary.averageDuration.botanicDuration)
            StatTile(label: "Check-ins", value: "\(Int(summary.averageCheckIns.rounded())) avg")
            StatTile(label: "Most felt", value: summary.mostFeltWord?.rawValue ?? "—")
        }
    }

    private func helpCard(_ help: HelpComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("Evenings with ")
                + Text(help.supplement.lowercased()).foregroundColor(Dusk.peachLight)
                + Text(" tended to feel \(help.isHelpful ? "calmer" : "different")."))
                .font(Dusk.serif(16)).foregroundStyle(Dusk.text)

            compareBar(label: "With \(firstWord(help.supplement))", value: help.withScore / 10,
                       gradient: [Dusk.peach, Dusk.pink], score: help.withScore, bright: true)
            compareBar(label: "Without", value: help.withoutScore / 10,
                       gradient: [Dusk.lavender.opacity(0.4), Dusk.lavender.opacity(0.4)],
                       score: help.withoutScore, bright: false)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmGlassCard(cornerRadius: 18)
    }

    private func compareBar(label: String, value: Double, gradient: [Color], score: Double, bright: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label).font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(bright ? 0.72 : 0.5))
                .frame(width: 92, alignment: .leading).lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * value))
                }
            }
            .frame(height: 9)
            Text(String(format: "%.1f", score)).font(Dusk.sans(11, .semibold))
                .foregroundStyle(bright ? Dusk.peachLight : Dusk.muted(0.55)).frame(width: 28, alignment: .trailing)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Your calmest evenings often share a place.")
                .font(Dusk.serif(16)).foregroundStyle(Dusk.text)
            FlowLayout(spacing: 7) {
                ForEach(summary.locationCounts) { item in
                    Text("\(item.label) · \(item.count)")
                        .font(Dusk.sans(12))
                        .foregroundStyle(Dusk.mintSoft)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Dusk.mint.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Dusk.mint.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 18)
    }

    private func barsCard(title: String, items: [LabeledCount], serif: Bool = false) -> some View {
        let maxCount = max(1, items.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 13) {
            Text(title.uppercased())
                .font(Dusk.sans(11, .bold)).tracking(1.4).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            ForEach(items) { item in
                HStack(spacing: 11) {
                    Text(item.label)
                        .font(serif ? Dusk.serifItalic(14) : Dusk.sans(12))
                        .foregroundStyle(Dusk.muted(0.88)).frame(width: 96, alignment: .leading).lineLimit(1)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.06))
                            Capsule().fill(LinearGradient(colors: [Dusk.peachLight, Dusk.pink],
                                                          startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, proxy.size.width * CGFloat(item.count) / CGFloat(maxCount)))
                        }
                    }
                    .frame(height: 9)
                    if !serif {
                        Text("\(item.count)").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5))
                            .frame(width: 16, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 18)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock").font(.system(size: 14)).foregroundStyle(Dusk.mint).padding(.top, 1)
            Text("Patterns are drawn from your own notes, on-device, never shared. They describe — they don't advise.")
                .font(Dusk.serifItalic(13.5)).foregroundStyle(Dusk.muted(0.62)).lineSpacing(2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassCard(fill: 0.04, cornerRadius: 17)
    }

    private func firstWord(_ s: String) -> String {
        s.split(separator: " ").first.map(String.init) ?? s
    }
}
