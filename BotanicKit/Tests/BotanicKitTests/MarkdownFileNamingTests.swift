import XCTest
@testable import BotanicKit

final class MarkdownFileNamingTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        return utcCalendar.date(from: comps)!
    }

    // MARK: - filename patterns

    func testDateTitlePattern() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 7, 4), title: "A slow morning", pattern: .dateTitle, calendar: utcCalendar
        )
        XCTAssertEqual(name, "2026-07-04 A slow morning.md")
    }

    func testTitleOnlyPattern() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 7, 4), title: "A slow morning", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "A slow morning.md")
    }

    func testDateOnlyPattern() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 7, 4), title: "Ignored title", pattern: .dateOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "2026-07-04.md")
    }

    func testPatternExamples() {
        XCTAssertEqual(MarkdownFilePattern.dateTitle.example, "2026-07-04 Title.md")
        XCTAssertEqual(MarkdownFilePattern.titleOnly.example, "Title.md")
        XCTAssertEqual(MarkdownFilePattern.dateOnly.example, "2026-07-04.md")
    }

    // MARK: - sanitization

    func testSanitizesForbiddenCharacters() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "A/B:C\\D?E%F*G|H\"I<J>K", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "ABCDEFGHIJK.md")
    }

    func testCollapsesWhitespaceAndTrims() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "  A   slow    morning  ", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "A slow morning.md")
    }

    func testEmptyTitleFallsBackToUntitled() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "Untitled.md")
    }

    func testTitleThatSanitizesToEmptyFallsBackToUntitled() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "///???", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "Untitled.md")
    }

    func testUnicodeAndEmojiPreserved() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "Café 🌿 día", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "Café 🌿 día.md")
    }

    func testControlCharactersStripped() {
        // Both the bell character and \n are classified as control characters and stripped outright
        // (not collapsed to a space), so adjacent letters end up joined.
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "A\u{0007}B\nC", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "ABC.md")
    }

    func testNewlineBetweenWordsSeparatedBySpaceIsCollapsed() {
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: "A \n B", pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, "A B.md")
    }

    func testTruncatesToEightyCharacters() {
        let longTitle = String(repeating: "a", count: 200)
        let name = MarkdownFileNaming.filename(
            date: date(2026, 1, 1), title: longTitle, pattern: .titleOnly, calendar: utcCalendar
        )
        XCTAssertEqual(name, String(repeating: "a", count: 80) + ".md")
    }

    func testDateFormattingIsLocaleIndependent() {
        var frenchCalendar = utcCalendar
        frenchCalendar.locale = Locale(identifier: "fr_FR")
        let name = MarkdownFileNaming.filename(
            date: date(2026, 12, 25), title: "Noël", pattern: .dateTitle, calendar: frenchCalendar
        )
        XCTAssertEqual(name, "2026-12-25 Noël.md")
    }

    // MARK: - collision resolution

    func testResolveCollisionReturnsUnchangedWhenUnique() {
        let result = MarkdownFileNaming.resolveCollision("Title.md", existing: ["Other.md"])
        XCTAssertEqual(result, "Title.md")
    }

    func testResolveCollisionAppendsSuffix() {
        let result = MarkdownFileNaming.resolveCollision("Title.md", existing: ["Title.md"])
        XCTAssertEqual(result, "Title (2).md")
    }

    func testResolveCollisionIncrementsUntilUnique() {
        let existing: Set<String> = ["Title.md", "Title (2).md", "Title (3).md"]
        let result = MarkdownFileNaming.resolveCollision("Title.md", existing: existing)
        XCTAssertEqual(result, "Title (4).md")
    }

    func testResolveCollisionOnAlreadySuffixedName() {
        let existing: Set<String> = ["Title (2).md"]
        let result = MarkdownFileNaming.resolveCollision("Title (2).md", existing: existing)
        XCTAssertEqual(result, "Title (2) (2).md")
    }

    func testResolveCollisionWithoutExtension() {
        let result = MarkdownFileNaming.resolveCollision("Title", existing: ["Title"])
        XCTAssertEqual(result, "Title (2)")
    }
}
