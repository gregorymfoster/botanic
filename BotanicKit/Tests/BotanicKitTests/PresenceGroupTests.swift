import XCTest
@testable import BotanicKit

final class PresenceGroupTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(PresenceGroup.body.label, "BODY")
        XCTAssertEqual(PresenceGroup.mind.label, "MIND")
        XCTAssertEqual(PresenceGroup.heart.label, "HEART")
    }

    func testWordCounts() {
        XCTAssertEqual(PresenceGroup.body.words.count, 5)
        XCTAssertEqual(PresenceGroup.mind.words.count, 5)
        XCTAssertEqual(PresenceGroup.heart.words.count, 5)
    }

    func testAllFifteenWordsAreUnique() {
        let all = PresenceGroup.allCases.flatMap(\.words)
        XCTAssertEqual(all.count, 15)
        XCTAssertEqual(Set(all).count, 15)
    }

    func testBodyGroupContents() {
        XCTAssertEqual(PresenceGroup.body.words, ["Warm", "Soft", "Heavy", "Tingly", "Restless"])
    }

    func testMindGroupContents() {
        XCTAssertEqual(PresenceGroup.mind.words, ["Clear", "Quiet", "Foggy", "Racing", "Curious"])
    }

    func testHeartGroupContents() {
        XCTAssertEqual(PresenceGroup.heart.words, ["Calm", "Tender", "Grateful", "Open", "Uneasy"])
    }

    func testPresenceTagAllUntouched() {
        XCTAssertEqual(PresenceTag.all, [
            "Grounded", "Calm", "Warm", "Clear", "Tired", "Restless",
            "Open", "Soft", "Alert", "Heavy", "Light", "Tearful"
        ])
    }
}
