import XCTest
@testable import BotanicKit

final class FormattingTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual((55 * 60).botanicDuration, "55m")
        XCTAssertEqual((2 * 3600 + 14 * 60).botanicDuration, "2h 14m")
        XCTAssertEqual((2 * 3600).botanicDuration, "2h")
        XCTAssertEqual(0.botanicDuration, "0m")
    }

    func testRelativeToNowFuture() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let in25 = now.addingTimeInterval(25 * 60)
        XCTAssertEqual(BotanicFormat.relativeToNow(in25, now: now), "in 25m")
    }

    func testRelativeToNowPastReadsNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let past = now.addingTimeInterval(-120)
        XCTAssertEqual(BotanicFormat.relativeToNow(past, now: now), "now")
    }

    func testFeelingValenceOrdering() {
        XCTAssertGreaterThan(FeelingWord.luminous.valence, FeelingWord.restless.valence)
        XCTAssertGreaterThan(FeelingWord.settled.valence, FeelingWord.tired.valence)
    }

    func testJournalPromptCyclesAndWraps() {
        XCTAssertEqual(JournalPrompt.at(0), JournalPrompt.all[0])
        XCTAssertEqual(JournalPrompt.at(JournalPrompt.all.count), JournalPrompt.all[0])
        XCTAssertEqual(JournalPrompt.at(-1), JournalPrompt.all[JournalPrompt.all.count - 1])
    }
}
