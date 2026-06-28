import Foundation

/// A framework-free snapshot of one completed experience, mapped from the app's SwiftData models so
/// insight math stays pure and testable. Only finished experiences (with `endedAt`) feed insights.
public struct ExperienceSnapshot: Sendable, Hashable {
    public var startedAt: Date
    public var endedAt: Date
    public var feeling: FeelingWord?
    public var locationContext: String?
    public var supplementNames: [String]
    public var checkInCount: Int
    /// One word the user reached for, gathered from feeling summaries and one-word journal entries.
    public var words: [String]

    public init(
        startedAt: Date,
        endedAt: Date,
        feeling: FeelingWord?,
        locationContext: String?,
        supplementNames: [String],
        checkInCount: Int,
        words: [String]
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.feeling = feeling
        self.locationContext = locationContext
        self.supplementNames = supplementNames
        self.checkInCount = checkInCount
        self.words = words
    }

    public var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    /// 0…1 felt score for this experience, from its summary feeling (falls back to neutral 0.5).
    public var feltScore: Double { feeling?.valence ?? 0.5 }
}

public struct LabeledCount: Sendable, Hashable, Identifiable {
    public let label: String
    public let count: Int
    public var id: String { label }
    public init(label: String, count: Int) {
        self.label = label
        self.count = count
    }
}

public struct TrendPoint: Sendable, Hashable, Identifiable {
    public let date: Date
    public let value: Double
    public var id: Date { date }
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// "With X vs without" felt comparison for a single supplement, scored 0…10.
public struct HelpComparison: Sendable, Hashable {
    public let supplement: String
    public let withScore: Double
    public let withoutScore: Double
    public init(supplement: String, withScore: Double, withoutScore: Double) {
        self.supplement = supplement
        self.withScore = withScore
        self.withoutScore = withoutScore
    }
    public var isHelpful: Bool { withScore > withoutScore }
}

/// Pure summary statistics over a set of completed experiences. Descriptive only — it never advises.
public struct InsightsSummary: Sendable {
    public let experienceCount: Int
    public let averageDuration: TimeInterval
    public let averageCheckIns: Double
    public let mostFeltWord: FeelingWord?
    public let feltTrend: [TrendPoint]
    public let topHelp: HelpComparison?
    public let locationCounts: [LabeledCount]
    public let topSupplements: [LabeledCount]
    public let topWords: [LabeledCount]
    public let trendingCalmer: Bool

    public var isEmpty: Bool { experienceCount == 0 }
}

/// Computes insights from completed experiences. All functions are pure and deterministic given the
/// inputs, so they can be unit-tested without SwiftData or a clock.
public enum InsightsEngine {
    public static func summary(for raw: [ExperienceSnapshot]) -> InsightsSummary {
        let experiences = raw.sorted { $0.startedAt < $1.startedAt }
        guard !experiences.isEmpty else {
            return InsightsSummary(
                experienceCount: 0, averageDuration: 0, averageCheckIns: 0,
                mostFeltWord: nil, feltTrend: [], topHelp: nil,
                locationCounts: [], topSupplements: [], topWords: [], trendingCalmer: false
            )
        }

        let avgDuration = experiences.map(\.duration).reduce(0, +) / Double(experiences.count)
        let avgCheckIns = Double(experiences.map(\.checkInCount).reduce(0, +)) / Double(experiences.count)

        let feltTrend = experiences.map { TrendPoint(date: $0.startedAt, value: $0.feltScore) }

        return InsightsSummary(
            experienceCount: experiences.count,
            averageDuration: avgDuration,
            averageCheckIns: avgCheckIns,
            mostFeltWord: mostFeltWord(experiences),
            feltTrend: feltTrend,
            topHelp: topHelp(experiences),
            locationCounts: locationCounts(experiences),
            topSupplements: topSupplements(experiences),
            topWords: topWords(experiences),
            trendingCalmer: trendingCalmer(feltTrend)
        )
    }

    static func mostFeltWord(_ experiences: [ExperienceSnapshot]) -> FeelingWord? {
        var counts: [FeelingWord: Int] = [:]
        for exp in experiences {
            if let f = exp.feeling { counts[f, default: 0] += 1 }
        }
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.rawValue > rhs.key.rawValue
        }?.key
    }

    static func locationCounts(_ experiences: [ExperienceSnapshot]) -> [LabeledCount] {
        tally(experiences.compactMap { $0.locationContext })
    }

    static func topSupplements(_ experiences: [ExperienceSnapshot], limit: Int = 5) -> [LabeledCount] {
        Array(tally(experiences.flatMap { $0.supplementNames }).prefix(limit))
    }

    static func topWords(_ experiences: [ExperienceSnapshot], limit: Int = 5) -> [LabeledCount] {
        Array(tally(experiences.flatMap { $0.words }).prefix(limit))
    }

    /// The supplement with the largest positive felt difference (with vs without), scored 0…10.
    static func topHelp(_ experiences: [ExperienceSnapshot]) -> HelpComparison? {
        let names = Set(experiences.flatMap { $0.supplementNames.map(normalize) })
        var best: HelpComparison?
        for name in names {
            let withIt = experiences.filter { $0.supplementNames.map(normalize).contains(name) }
            let withoutIt = experiences.filter { !$0.supplementNames.map(normalize).contains(name) }
            guard !withIt.isEmpty, !withoutIt.isEmpty else { continue }
            let withScore = average(withIt.map { $0.feltScore }) * 10
            let withoutScore = average(withoutIt.map { $0.feltScore }) * 10
            let candidate = HelpComparison(
                supplement: displayName(name, in: experiences),
                withScore: withScore,
                withoutScore: withoutScore
            )
            if candidate.withScore - candidate.withoutScore > (best.map { $0.withScore - $0.withoutScore } ?? 0) {
                best = candidate
            }
        }
        return best
    }

    /// Felt trend is rising if the mean of the back half exceeds the front half.
    static func trendingCalmer(_ trend: [TrendPoint]) -> Bool {
        guard trend.count >= 2 else { return false }
        let mid = trend.count / 2
        let front = average(trend.prefix(mid).map(\.value))
        let back = average(trend.suffix(trend.count - mid).map(\.value))
        return back > front
    }

    // MARK: - Helpers

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func displayName(_ normalized: String, in experiences: [ExperienceSnapshot]) -> String {
        for exp in experiences {
            if let match = exp.supplementNames.first(where: { normalize($0) == normalized }) {
                return match
            }
        }
        return normalized.capitalized
    }

    /// Frequency tally sorted by count desc, then label asc for stable output.
    private static func tally(_ items: [String]) -> [LabeledCount] {
        var counts: [String: (display: String, count: Int)] = [:]
        for item in items {
            let key = normalize(item)
            guard !key.isEmpty else { continue }
            let existing = counts[key]
            counts[key] = (existing?.display ?? item, (existing?.count ?? 0) + 1)
        }
        return counts.values
            .map { LabeledCount(label: $0.display, count: $0.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.label < $1.label }
    }
}
