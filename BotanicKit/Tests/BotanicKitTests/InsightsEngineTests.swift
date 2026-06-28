import XCTest
@testable import BotanicKit

final class InsightsEngineTests: XCTestCase {
    private func snap(
        dayOffset: Int,
        hours: Double,
        feeling: FeelingWord?,
        location: String? = nil,
        supplements: [String] = [],
        checkIns: Int = 0,
        words: [String] = []
    ) -> ExperienceSnapshot {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let start = base.addingTimeInterval(Double(dayOffset) * 86_400)
        return ExperienceSnapshot(
            startedAt: start,
            endedAt: start.addingTimeInterval(hours * 3600),
            feeling: feeling,
            locationContext: location,
            supplementNames: supplements,
            checkInCount: checkIns,
            words: words
        )
    }

    func testEmptyInputProducesEmptySummary() {
        let summary = InsightsEngine.summary(for: [])
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.experienceCount, 0)
        XCTAssertNil(summary.mostFeltWord)
        XCTAssertNil(summary.topHelp)
    }

    func testAveragesDurationAndCheckIns() {
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 2, feeling: .calm, checkIns: 2),
            snap(dayOffset: 1, hours: 3, feeling: .settled, checkIns: 4)
        ])
        XCTAssertEqual(summary.experienceCount, 2)
        XCTAssertEqual(summary.averageDuration, 2.5 * 3600, accuracy: 0.5)
        XCTAssertEqual(summary.averageCheckIns, 3, accuracy: 0.0001)
    }

    func testMostFeltWordPicksHighestFrequency() {
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 1, feeling: .settled),
            snap(dayOffset: 1, hours: 1, feeling: .settled),
            snap(dayOffset: 2, hours: 1, feeling: .warm)
        ])
        XCTAssertEqual(summary.mostFeltWord, .settled)
    }

    func testTopHelpDetectsPositiveDifference() throws {
        // Chamomile evenings feel calmer than those without it.
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 2, feeling: .settled, supplements: ["Chamomile tea"]),
            snap(dayOffset: 1, hours: 2, feeling: .calm, supplements: ["Chamomile tea", "Magnesium"]),
            snap(dayOffset: 2, hours: 2, feeling: .restless, supplements: ["Magnesium"]),
            snap(dayOffset: 3, hours: 2, feeling: .tired, supplements: ["Magnesium"])
        ])
        let help = try XCTUnwrap(summary.topHelp)
        XCTAssertEqual(help.supplement.lowercased(), "chamomile tea")
        XCTAssertTrue(help.isHelpful)
    }

    func testTopHelpNilWhenNoContrast() {
        // Every experience has the same single supplement: no "without" group, so no comparison.
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 2, feeling: .settled, supplements: ["Magnesium"]),
            snap(dayOffset: 1, hours: 2, feeling: .calm, supplements: ["Magnesium"])
        ])
        XCTAssertNil(summary.topHelp)
    }

    func testLocationAndSupplementTalliesAreCountSorted() {
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 1, feeling: .calm, location: "Home", supplements: ["Magnesium", "Tea"]),
            snap(dayOffset: 1, hours: 1, feeling: .calm, location: "Home", supplements: ["Magnesium"]),
            snap(dayOffset: 2, hours: 1, feeling: .calm, location: "Garden", supplements: ["Magnesium"])
        ])
        XCTAssertEqual(summary.locationCounts.first?.label, "Home")
        XCTAssertEqual(summary.locationCounts.first?.count, 2)
        XCTAssertEqual(summary.topSupplements.first?.label, "Magnesium")
        XCTAssertEqual(summary.topSupplements.first?.count, 3)
    }

    func testTrendingCalmerWhenBackHalfHigher() {
        let rising = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 1, feeling: .restless),
            snap(dayOffset: 1, hours: 1, feeling: .tired),
            snap(dayOffset: 2, hours: 1, feeling: .calm),
            snap(dayOffset: 3, hours: 1, feeling: .luminous)
        ])
        XCTAssertTrue(rising.trendingCalmer)

        let falling = InsightsEngine.summary(for: [
            snap(dayOffset: 0, hours: 1, feeling: .luminous),
            snap(dayOffset: 1, hours: 1, feeling: .calm),
            snap(dayOffset: 2, hours: 1, feeling: .tired),
            snap(dayOffset: 3, hours: 1, feeling: .restless)
        ])
        XCTAssertFalse(falling.trendingCalmer)
    }

    func testFeltTrendIsChronological() {
        let summary = InsightsEngine.summary(for: [
            snap(dayOffset: 2, hours: 1, feeling: .calm),
            snap(dayOffset: 0, hours: 1, feeling: .restless),
            snap(dayOffset: 1, hours: 1, feeling: .warm)
        ])
        let dates = summary.feltTrend.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }
}
