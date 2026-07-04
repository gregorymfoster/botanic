import XCTest
@testable import BotanicKit

final class SupplementRecentsTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ name: String, daysAgo: Double, useCount: Int = 1) -> SupplementLibrarySnapshot {
        SupplementLibrarySnapshot(
            name: name,
            lastAmount: nil,
            lastIntention: nil,
            useCount: useCount,
            lastUsedAt: base.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    func testOrdersMostRecentFirst() {
        let items = [
            item("Magnesium", daysAgo: 3),
            item("Chamomile", daysAgo: 1),
            item("Ashwagandha", daysAgo: 5)
        ]
        let result = SupplementRecents.recents(items).map(\.name)
        XCTAssertEqual(result, ["Chamomile", "Magnesium", "Ashwagandha"])
    }

    func testTiesKeepStableOrder() {
        let sameTime = base
        let items = [
            SupplementLibrarySnapshot(name: "A", lastAmount: nil, lastIntention: nil, useCount: 1, lastUsedAt: sameTime),
            SupplementLibrarySnapshot(name: "B", lastAmount: nil, lastIntention: nil, useCount: 1, lastUsedAt: sameTime),
            SupplementLibrarySnapshot(name: "C", lastAmount: nil, lastIntention: nil, useCount: 1, lastUsedAt: sameTime)
        ]
        XCTAssertEqual(SupplementRecents.recents(items).map(\.name), ["A", "B", "C"])
    }

    func testQueryFiltersByPrefixOfAnyWord() {
        let items = [
            item("Magnesium Glycinate", daysAgo: 1),
            item("Chamomile Tea", daysAgo: 2),
            item("Ashwagandha", daysAgo: 3)
        ]
        let result = SupplementRecents.recents(items, matching: "gly").map(\.name)
        XCTAssertEqual(result, ["Magnesium Glycinate"])
    }

    func testQueryFiltersBySubstringAnywhereInName() {
        let items = [item("Magnesium Glycinate", daysAgo: 1), item("Chamomile Tea", daysAgo: 2)]
        let result = SupplementRecents.recents(items, matching: "amomi").map(\.name)
        XCTAssertEqual(result, ["Chamomile Tea"])
    }

    func testQueryIsCaseInsensitive() {
        let items = [item("Magnesium", daysAgo: 1)]
        XCTAssertEqual(SupplementRecents.recents(items, matching: "MAG").map(\.name), ["Magnesium"])
    }

    func testEmptyQueryReturnsAll() {
        let items = [item("Magnesium", daysAgo: 1), item("Chamomile", daysAgo: 2)]
        XCTAssertEqual(SupplementRecents.recents(items, matching: "").count, 2)
    }

    func testQueryWithNoMatchesReturnsEmpty() {
        let items = [item("Magnesium", daysAgo: 1)]
        XCTAssertTrue(SupplementRecents.recents(items, matching: "zzz").isEmpty)
    }

    func testLimitCapsResultCount() {
        let items = [
            item("A", daysAgo: 1), item("B", daysAgo: 2), item("C", daysAgo: 3)
        ]
        XCTAssertEqual(SupplementRecents.recents(items, limit: 2).map(\.name), ["A", "B"])
    }

    func testLimitLargerThanCountReturnsAll() {
        let items = [item("A", daysAgo: 1)]
        XCTAssertEqual(SupplementRecents.recents(items, limit: 10).count, 1)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(SupplementRecents.recents([]).isEmpty)
    }
}
