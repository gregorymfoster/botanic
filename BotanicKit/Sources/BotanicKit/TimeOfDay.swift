import Foundation

/// A single source of truth for "what part of the day is this hour in," used to derive default
/// experience titles, the Today tab's greeting, and end-of-experience summary copy. Call sites
/// historically each had their own inline hour-bucket switch, and two of them disagree at the
/// evening/night boundary (21 vs 22) — this enum captures the most granular boundary set found
/// across all of them (`.eveningLate` isolates the 21..<22 hour that only some call sites treat as
/// "night"), and each call site's mapping function reduces those cases back down to its own historic
/// strings so every call site's output stays byte-identical to what it produced before.
public enum TimeOfDay: Sendable, Equatable {
    case earlyMorning   // 22:00–4:59 ("late night" / "night")
    case morning        // 5:00–11:59
    case afternoon       // 12:00–16:59
    case evening         // 17:00–20:59
    case eveningLate     // 21:00–21:59 — some call sites still say "evening", others "night"

    /// Buckets an hour (0...23) into a `TimeOfDay`. The boundaries — 5, 12, 17, 21, 22 — are the
    /// union of every boundary found across `ExperienceStore.defaultTitle`, `TodayView.dayPart`, and
    /// `ExperienceSummaryGenerator`/`FoundationModelsSummarizer`'s inline time-of-day switches.
    public init(hour: Int) {
        switch hour {
        case 5..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        case 21..<22: self = .eveningLate
        default: self = .earlyMorning
        }
    }

    public init(date: Date, calendar: Calendar = .current) {
        self.init(hour: calendar.component(.hour, from: date))
    }

    // MARK: - Call site mappings

    /// `ExperienceStore.defaultTitle(for:)`'s exact strings: 5..<12 "Slow morning", 12..<17
    /// "Afternoon", 17..<22 "Evening at home", else "Late night". Treats `.eveningLate` as evening.
    public static func defaultExperienceTitle(for date: Date, calendar: Calendar = .current) -> String {
        switch TimeOfDay(date: date, calendar: calendar) {
        case .morning: return "Slow morning"
        case .afternoon: return "Afternoon"
        case .evening, .eveningLate: return "Evening at home"
        case .earlyMorning: return "Late night"
        }
    }

    /// `TodayView.dayPart`'s exact strings: 5..<12 "morning", 12..<17 "afternoon", 17..<22 "evening",
    /// else "night". Treats `.eveningLate` as evening, matching the original `17..<22` range.
    public var todayGreetingWord: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening, .eveningLate: return "evening"
        case .earlyMorning: return "night"
        }
    }

    /// `ExperienceSummaryGenerator`/`FoundationModelsSummarizer`'s exact strings: 5..<12 "morning",
    /// 12..<17 "afternoon", 17..<21 "evening", else "night". Treats `.eveningLate` as night — this is
    /// the one boundary where the two families of call sites disagree (21..<22 reads as "evening"
    /// for `defaultExperienceTitle`/`todayGreetingWord` but "night" here).
    public var summaryWord: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        case .eveningLate, .earlyMorning: return "night"
        }
    }
}
