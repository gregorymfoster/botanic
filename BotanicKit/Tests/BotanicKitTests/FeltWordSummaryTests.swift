import XCTest
@testable import BotanicKit

final class FeltWordSummaryTests: XCTestCase {
    func testFrequencyDescending() {
        let words = [["Calm", "Warm"], ["Calm"], ["Calm", "Tender"]]
        XCTAssertEqual(FeltWordSummary.top(from: words, limit: 1), ["Calm"])
    }

    func testTopReturnsUpToLimitOrderedByFrequency() {
        let words = [["Calm", "Warm", "Tender"], ["Calm", "Warm"], ["Calm"]]
        XCTAssertEqual(FeltWordSummary.top(from: words, limit: 2), ["Calm", "Warm"])
    }

    func testTiesBreakByRecencyLaterWins() {
        // "Warm" and "Tender" both appear once, but Tender is from the later check-in.
        let words = [["Warm"], ["Tender"]]
        XCTAssertEqual(FeltWordSummary.top(from: words, limit: 1), ["Tender"])
    }

    func testDedupeIsCaseInsensitivePreservingFirstSeenCasing() {
        let words = [["calm"], ["Calm"], ["CALM"]]
        XCTAssertEqual(FeltWordSummary.top(from: words, limit: 1), ["calm"])
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(FeltWordSummary.top(from: []).isEmpty)
        XCTAssertTrue(FeltWordSummary.top(from: [[], []]).isEmpty)
    }

    func testDefaultLimitIsThree() {
        let words = [["A", "B", "C", "D"]]
        XCTAssertEqual(FeltWordSummary.top(from: words).count, 3)
    }

    func testLimitLargerThanAvailableWordsReturnsAll() {
        let words = [["A", "B"]]
        XCTAssertEqual(FeltWordSummary.top(from: words, limit: 10).count, 2)
    }
}
