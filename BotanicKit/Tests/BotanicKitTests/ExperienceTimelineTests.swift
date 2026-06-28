import XCTest
@testable import BotanicKit

final class ExperienceTimelineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func input(_ minutes: Double, _ kind: TimelineEntry.Kind, id: UUID = UUID()) -> TimelineInput {
        TimelineInput(id: id, date: start.addingTimeInterval(minutes * 60), kind: kind)
    }

    func testEmptyInputProducesEmptyTimeline() {
        XCTAssertTrue(ExperienceTimeline.build([], start: start).isEmpty)
    }

    func testEntriesAreChronological() {
        let timeline = ExperienceTimeline.build([
            input(90, .journal(text: "late", isOneWord: false)),
            input(0, .supplement(name: "Magnesium", howTaking: "2 caps")),
            input(45, .checkIn(word: "Settled"))
        ], start: start)

        XCTAssertEqual(timeline.map(\.date), timeline.map(\.date).sorted())
        if case .supplement(let name, _) = timeline.first?.kind {
            XCTAssertEqual(name, "Magnesium")
        } else {
            XCTFail("Expected the earliest entry to be the supplement")
        }
    }

    func testOffsetIsMeasuredFromStart() {
        let timeline = ExperienceTimeline.build([
            input(0, .supplement(name: "Magnesium", howTaking: nil)),
            input(75, .checkIn(word: "Calm"))
        ], start: start)

        XCTAssertEqual(timeline[0].offset, 0, accuracy: 0.001)
        XCTAssertEqual(timeline[1].offset, 75 * 60, accuracy: 0.001)
    }

    func testOffsetClampsAtZeroForPreStartMoments() {
        let timeline = ExperienceTimeline.build([
            input(-30, .journal(text: "before", isOneWord: false))
        ], start: start)

        XCTAssertEqual(timeline[0].offset, 0, accuracy: 0.001)
    }

    func testEqualDatesBreakTieByIdForStableOrder() {
        let early = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let late = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000")!
        let inputs = [
            input(10, .checkIn(word: "Warm"), id: late),
            input(10, .checkIn(word: "Calm"), id: early)
        ]

        let forward = ExperienceTimeline.build(inputs, start: start).map(\.id)
        let reversed = ExperienceTimeline.build(inputs.reversed(), start: start).map(\.id)
        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.first, early)
    }
}
