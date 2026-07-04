import XCTest
@testable import BotanicKit

final class TitleSourceTests: XCTestCase {
    func testRawValueRoundTrip() {
        for source in [TitleSource.ai, TitleSource.user] {
            let raw = source.rawValue
            XCTAssertEqual(TitleSource(rawValue: raw), source)
        }
    }
}
