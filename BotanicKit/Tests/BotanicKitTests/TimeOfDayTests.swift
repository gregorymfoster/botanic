import XCTest
@testable import BotanicKit

final class TimeOfDayTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(hour: Int, y: Int = 2026, m: Int = 7, d: Int = 4) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour; comps.minute = 0
        return utcCalendar.date(from: comps)!
    }

    // Boundary hours to check: 0, 4, 5, 11, 12, 16, 17, 21, 22, 23.
    private let boundaryHours = [0, 4, 5, 11, 12, 16, 17, 21, 22, 23]

    // MARK: - Bucket boundaries themselves

    func testBucketBoundaries() {
        let expected: [Int: TimeOfDay] = [
            0: .earlyMorning,
            4: .earlyMorning,
            5: .morning,
            11: .morning,
            12: .afternoon,
            16: .afternoon,
            17: .evening,
            21: .eveningLate,
            22: .earlyMorning,
            23: .earlyMorning
        ]
        for hour in boundaryHours {
            XCTAssertEqual(TimeOfDay(hour: hour), expected[hour], "hour \(hour)")
        }
    }

    // MARK: - ExperienceStore.defaultTitle(for:) — "Slow morning" / "Afternoon" / "Evening at home" / "Late night"

    func testDefaultExperienceTitleMatchesOriginalExperienceStoreBehavior() {
        let expected: [Int: String] = [
            0: "Late night",
            4: "Late night",
            5: "Slow morning",
            11: "Slow morning",
            12: "Afternoon",
            16: "Afternoon",
            17: "Evening at home",
            // ExperienceStore's original range was 17..<22, so hour 21 is still "Evening at home".
            21: "Evening at home",
            22: "Late night",
            23: "Late night"
        ]
        for hour in boundaryHours {
            XCTAssertEqual(
                TimeOfDay.defaultExperienceTitle(for: date(hour: hour), calendar: utcCalendar),
                expected[hour],
                "hour \(hour)"
            )
        }
    }

    // MARK: - TodayView.dayPart — "morning" / "afternoon" / "evening" / "night"

    func testTodayGreetingWordMatchesOriginalTodayViewBehavior() {
        let expected: [Int: String] = [
            0: "night",
            4: "night",
            5: "morning",
            11: "morning",
            12: "afternoon",
            16: "afternoon",
            17: "evening",
            // TodayView's original range was also 17..<22, so hour 21 is still "evening" — agrees
            // with defaultExperienceTitle here, but both disagree with summaryWord below.
            21: "evening",
            22: "night",
            23: "night"
        ]
        for hour in boundaryHours {
            let calendar = utcCalendar
            let word = TimeOfDay(hour: calendar.component(.hour, from: date(hour: hour))).todayGreetingWord
            XCTAssertEqual(word, expected[hour], "hour \(hour)")
        }
    }

    // MARK: - ExperienceSummaryGenerator / FoundationModelsSummarizer — "morning" / "afternoon" / "evening" / "night"

    func testSummaryWordMatchesOriginalExperienceSummaryGeneratorBehavior() {
        let expected: [Int: String] = [
            0: "night",
            4: "night",
            5: "morning",
            11: "morning",
            12: "afternoon",
            16: "afternoon",
            17: "evening",
            20: "evening",
            // Both ExperienceSummaryGenerator and FoundationModelsSummarizer used 17..<21, so hour 21
            // reads as "night" here — this is the one hour where these two call sites disagree with
            // ExperienceStore.defaultTitle and TodayView.dayPart (which both say "evening"/"Evening
            // at home" through hour 21). That disagreement is expected and preserved, not unified.
            21: "night",
            22: "night",
            23: "night"
        ]
        for hour in boundaryHours {
            XCTAssertEqual(
                TimeOfDay(date: date(hour: hour), calendar: utcCalendar).summaryWord,
                expected[hour],
                "hour \(hour)"
            )
        }
    }

    func testCalendarParameterDefaultsToCurrent() {
        // Just confirms the default-parameter overload compiles and runs without a calendar passed.
        _ = TimeOfDay.defaultExperienceTitle(for: Date())
        _ = TimeOfDay(date: Date())
    }
}
