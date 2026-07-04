import XCTest
@testable import BotanicKit

final class ExperienceSummaryGeneratorTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(hour: Int, y: Int = 2026, m: Int = 7, d: Int = 4) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour; comps.minute = 15
        return utcCalendar.date(from: comps)!
    }

    /// A full, representative input pinned to an exact expected output. If this fails after a
    /// template change, update the pin deliberately rather than loosening the assertion.
    func testFullInputMatchesPinnedOutput() {
        let input = ExperienceSummaryInput(
            supplements: ["Magnesium", "Chamomile"],
            checkInWords: [["Restless", "Uneasy"], ["Calm", "Warm"]],
            valenceTrajectory: [0.3, 0.15, 0.75],
            notes: ["The tea, finally, made the difference."],
            startedAt: date(hour: 7),
            duration: 3600,
            calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertEqual(output.title, "A slow morning that finally settled")
        XCTAssertEqual(
            output.subtitle,
            "Magnesium then Chamomile. Restless early on, calm by the second check-in. The tea was the turn."
        )
    }

    func testAsyncProtocolConformanceMatchesStaticFunction() async throws {
        let input = ExperienceSummaryInput(
            supplements: ["Magnesium"],
            checkInWords: [["Calm"]],
            valenceTrajectory: [0.6],
            notes: [],
            startedAt: date(hour: 20),
            duration: 1800,
            calendar: utcCalendar
        )
        let summarizer = DeterministicExperienceSummarizer()
        let output = try await summarizer.summarize(input)
        XCTAssertEqual(output, DeterministicExperienceSummarizer.summarize(input))
    }

    func testTimeOfDayBoundaries() {
        func summary(hour: Int) -> ExperienceSummaryOutput {
            let input = ExperienceSummaryInput(
                supplements: [], checkInWords: [], valenceTrajectory: [],
                notes: [], startedAt: date(hour: hour), duration: 0, calendar: utcCalendar
            )
            return DeterministicExperienceSummarizer.summarize(input)
        }
        XCTAssertTrue(summary(hour: 5).title.contains("morning"))
        XCTAssertTrue(summary(hour: 11).title.contains("morning"))
        XCTAssertTrue(summary(hour: 12).title.contains("afternoon"))
        XCTAssertTrue(summary(hour: 16).title.contains("afternoon"))
        XCTAssertTrue(summary(hour: 17).title.contains("evening"))
        XCTAssertTrue(summary(hour: 20).title.contains("evening"))
        XCTAssertTrue(summary(hour: 21).title.contains("night"))
        XCTAssertTrue(summary(hour: 4).title.contains("night"))
    }

    func testZeroCheckInsProducesNonEmptyOutput() {
        let input = ExperienceSummaryInput(
            supplements: ["Magnesium"],
            checkInWords: [],
            valenceTrajectory: [],
            notes: [],
            startedAt: date(hour: 9),
            duration: 900,
            calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertFalse(output.title.isEmpty)
        XCTAssertFalse(output.subtitle.isEmpty)
        XCTAssertFalse(output.subtitle.contains("  "))
    }

    func testZeroSupplementsProducesNonEmptyOutput() {
        let input = ExperienceSummaryInput(
            supplements: [],
            checkInWords: [["Calm"], ["Settled"]],
            valenceTrajectory: [0.6, 0.62],
            notes: [],
            startedAt: date(hour: 14),
            duration: 1200,
            calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertFalse(output.title.isEmpty)
        XCTAssertFalse(output.subtitle.isEmpty)
        XCTAssertFalse(output.subtitle.contains("  "))
    }

    func testNoNotesProducesNonEmptyOutputWithoutDoubleSpaces() {
        let input = ExperienceSummaryInput(
            supplements: ["Ashwagandha"],
            checkInWords: [["Tired"]],
            valenceTrajectory: [0.4],
            notes: [],
            startedAt: date(hour: 22),
            duration: 600,
            calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertFalse(output.title.isEmpty)
        XCTAssertFalse(output.subtitle.isEmpty)
        XCTAssertFalse(output.subtitle.contains("  "))
    }

    func testCompletelyEmptyInputProducesNonEmptyOutput() {
        let input = ExperienceSummaryInput(
            supplements: [], checkInWords: [], valenceTrajectory: [],
            notes: [], startedAt: date(hour: 3), duration: 0, calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertFalse(output.title.isEmpty)
        XCTAssertFalse(output.subtitle.isEmpty)
    }

    func testTitleNeverHasTrailingPeriod() {
        let inputs: [ExperienceSummaryInput] = [
            ExperienceSummaryInput(
                supplements: ["Magnesium"], checkInWords: [["Calm"]], valenceTrajectory: [0.3, 0.8],
                notes: [], startedAt: date(hour: 8), duration: 60, calendar: utcCalendar
            ),
            ExperienceSummaryInput(
                supplements: [], checkInWords: [], valenceTrajectory: [],
                notes: [], startedAt: date(hour: 13), duration: 60, calendar: utcCalendar
            )
        ]
        for input in inputs {
            let output = DeterministicExperienceSummarizer.summarize(input)
            XCTAssertFalse(output.title.hasSuffix("."))
        }
    }

    func testSingleSupplementSentence() {
        let input = ExperienceSummaryInput(
            supplements: ["Magnesium"], checkInWords: [], valenceTrajectory: [],
            notes: [], startedAt: date(hour: 9), duration: 60, calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertTrue(output.subtitle.contains("Magnesium."))
    }

    func testLongNoteFragmentTruncatesAtWordBoundary() {
        let longNote = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let input = ExperienceSummaryInput(
            supplements: [], checkInWords: [], valenceTrajectory: [],
            notes: [longNote], startedAt: date(hour: 9), duration: 60, calendar: utcCalendar
        )
        let output = DeterministicExperienceSummarizer.summarize(input)
        XCTAssertTrue(output.subtitle.contains("was the turn."))
        XCTAssertFalse(output.subtitle.contains("  "))
    }
}
