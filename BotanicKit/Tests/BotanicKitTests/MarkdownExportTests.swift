import XCTest
@testable import BotanicKit

final class MarkdownExportTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(hour: Int, minute: Int = 0, y: Int = 2026, m: Int = 7, d: Int = 4) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour; comps.minute = minute
        return utcCalendar.date(from: comps)!
    }

    private func emptyInput(
        title: String = "Evening at home",
        subtitle: String? = nil,
        startedAt: Date,
        duration: TimeInterval = 0,
        feltWords: [String] = [],
        feltSummary: FeelingWord? = nil,
        noteToFuture: String? = nil
    ) -> MarkdownExportInput {
        MarkdownExportInput(
            title: title,
            subtitle: subtitle,
            startedAt: startedAt,
            duration: duration,
            feltWords: feltWords,
            feltSummary: feltSummary,
            supplements: [],
            checkIns: [],
            journalEntries: [],
            noteToFuture: noteToFuture
        )
    }

    // MARK: - Empty state

    func testEmptyExperienceProducesSaneMarkdown() {
        let input = emptyInput(title: "Slow morning", startedAt: date(hour: 8, minute: 0))
        let markdown = MarkdownExport.experience(input)

        XCTAssertTrue(markdown.hasPrefix("# Slow morning"))
        XCTAssertTrue(markdown.contains("| Date |"))
        XCTAssertTrue(markdown.contains("| Duration | 0m |"))
        XCTAssertFalse(markdown.contains("## Supplements"))
        XCTAssertFalse(markdown.contains("## Timeline"))
        XCTAssertFalse(markdown.contains("## Note to future me"))
        XCTAssertFalse(markdown.contains("Felt words"))
        XCTAssertTrue(markdown.contains("Exported from Botanic"))
    }

    // MARK: - Felt words fallback

    /// When `feltWords` (the chip-based list) is empty but a one-word `feltSummary` was recorded,
    /// the exported table falls back to that single word.
    func testFeltWordsFallsBackToFeltSummaryWhenChipsEmpty() {
        let input = emptyInput(
            startedAt: date(hour: 9),
            feltWords: [],
            feltSummary: .settled
        )
        let markdown = MarkdownExport.experience(input)
        XCTAssertTrue(markdown.contains("| Felt words | Settled |"))
    }

    func testFeltWordsPrefersChipsOverFeltSummaryWhenBothPresent() {
        let input = emptyInput(
            startedAt: date(hour: 9),
            feltWords: ["Calm", "Warm"],
            feltSummary: .settled
        )
        let markdown = MarkdownExport.experience(input)
        XCTAssertTrue(markdown.contains("| Felt words | Calm, Warm |"))
        XCTAssertFalse(markdown.contains("Settled"))
    }

    func testNoFeltWordsRowWhenBothEmpty() {
        let input = emptyInput(startedAt: date(hour: 9), feltWords: [], feltSummary: nil)
        let markdown = MarkdownExport.experience(input)
        XCTAssertFalse(markdown.contains("Felt words"))
    }

    // MARK: - Timeline interleaving

    func testTimelineInterleavesSupplementsCheckInsAndJournalEntriesChronologically() {
        let start = date(hour: 18, minute: 0)
        let input = MarkdownExportInput(
            title: "Evening wind-down",
            subtitle: nil,
            startedAt: start,
            duration: 2 * 3600,
            feltWords: [],
            feltSummary: nil,
            supplements: [
                MarkdownExportInput.Supplement(
                    name: "Magnesium",
                    howTaking: "1 capsule",
                    intention: "Sleep",
                    takenAt: date(hour: 18, minute: 5),
                    effectiveTime: date(hour: 18, minute: 5)
                )
            ],
            checkIns: [
                MarkdownExportInput.CheckIn(
                    createdAt: date(hour: 19, minute: 0),
                    valence: 0.6,
                    intensity: 0.3,
                    bodyLoad: 0.2,
                    feeling: .calm,
                    tags: ["Warm"],
                    note: nil
                )
            ],
            journalEntries: [
                MarkdownExportInput.JournalEntry(
                    createdAt: date(hour: 18, minute: 30),
                    text: "Feeling the tea kick in."
                )
            ],
            noteToFuture: nil
        )

        let markdown = MarkdownExport.experience(input)
        guard let timelineRange = markdown.range(of: "## Timeline") else {
            return XCTFail("Expected a Timeline section")
        }
        let timelineSection = markdown[timelineRange.upperBound...]

        // Journal entry (18:30) must precede the check-in (19:00) in the rendered timeline.
        guard let journalRange = timelineSection.range(of: "Feeling the tea kick in."),
              let checkInRange = timelineSection.range(of: "**Check-in**") else {
            return XCTFail("Expected both a journal line and a check-in line in the timeline")
        }
        XCTAssertTrue(journalRange.lowerBound < checkInRange.lowerBound)

        // Supplements render in their own section, not the timeline.
        XCTAssertTrue(markdown.contains("## Supplements"))
        XCTAssertTrue(markdown.contains("**Magnesium**"))
        XCTAssertTrue(markdown.contains("Intention: Sleep"))
    }

    func testTimelineOrdersMultipleCheckInsAndJournalEntriesByCreatedAt() {
        let input = MarkdownExportInput(
            title: "Test",
            subtitle: nil,
            startedAt: date(hour: 10),
            duration: 3600,
            feltWords: [],
            feltSummary: nil,
            supplements: [],
            checkIns: [
                MarkdownExportInput.CheckIn(
                    createdAt: date(hour: 12), valence: 0.5, intensity: 0.5, bodyLoad: 0.5,
                    feeling: nil, tags: [], note: nil
                ),
                MarkdownExportInput.CheckIn(
                    createdAt: date(hour: 10, minute: 30), valence: 0.5, intensity: 0.5, bodyLoad: 0.5,
                    feeling: nil, tags: [], note: nil
                )
            ],
            journalEntries: [
                MarkdownExportInput.JournalEntry(createdAt: date(hour: 11), text: "Middle note")
            ],
            noteToFuture: nil
        )

        let markdown = MarkdownExport.experience(input)
        guard let timelineRange = markdown.range(of: "## Timeline") else {
            return XCTFail("Expected a Timeline section")
        }
        let lines = markdown[timelineRange.upperBound...]
            .split(separator: "\n")
            .filter { $0.hasPrefix("- ") }

        // Expect: 10:30 check-in, 11:00 journal, 12:00 check-in — three top-level timeline lines.
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains("Check-in"))
        XCTAssertTrue(lines[1].contains("Middle note"))
        XCTAssertTrue(lines[2].contains("Check-in"))
    }
}
