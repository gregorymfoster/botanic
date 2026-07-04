import XCTest
@testable import BotanicKit

final class NotificationPolicyTests: XCTestCase {
    private func date(_ offsetSeconds: TimeInterval, from base: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> Date {
        base.addingTimeInterval(offsetSeconds)
    }

    private var base: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    // MARK: - quietSuggestionFireDate

    func testQuietSuggestionFireDateReturnsNilWhenDisabled() {
        let result = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: base,
            quietSuggestHours: 3,
            isEnabled: false,
            now: base
        )
        XCTAssertNil(result)
    }

    func testQuietSuggestionFireDateComputesHoursAfterLastEvent() {
        let result = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: base,
            quietSuggestHours: 3,
            isEnabled: true,
            now: base
        )
        XCTAssertEqual(result, base.addingTimeInterval(3 * 3600))
    }

    func testQuietSuggestionFireDateClampsNonPositiveHoursToOne() {
        let zeroHours = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: base,
            quietSuggestHours: 0,
            isEnabled: true,
            now: base
        )
        XCTAssertEqual(zeroHours, base.addingTimeInterval(1 * 3600))

        let negativeHours = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: base,
            quietSuggestHours: -5,
            isEnabled: true,
            now: base
        )
        XCTAssertEqual(negativeHours, base.addingTimeInterval(1 * 3600))
    }

    func testQuietSuggestionFireDateReturnsNilWhenAlreadyPast() {
        // lastEventAt far enough in the past that lastEventAt + hours < now.
        let lastEventAt = date(-10 * 3600)
        let result = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: lastEventAt,
            quietSuggestHours: 3,
            isEnabled: true,
            now: base
        )
        XCTAssertNil(result)
    }

    func testQuietSuggestionFireDateReturnsNilExactlyAtNow() {
        // fireDate == now should not fire (guard is strictly >).
        let lastEventAt = date(-3 * 3600)
        let result = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: lastEventAt,
            quietSuggestHours: 3,
            isEnabled: true,
            now: base
        )
        XCTAssertNil(result)
    }

    func testQuietSuggestionFireDateReturnsDateJustAfterNow() {
        let lastEventAt = date(-3 * 3600 + 1)
        let result = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: lastEventAt,
            quietSuggestHours: 3,
            isEnabled: true,
            now: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result, lastEventAt.addingTimeInterval(3 * 3600))
    }

    // MARK: - shouldScheduleSupplementAlert

    func testShouldScheduleSupplementAlertTrueWhenEnabledAndFuture() {
        XCTAssertTrue(NotificationPolicy.shouldScheduleSupplementAlert(
            scheduledFor: date(60),
            now: base,
            alertsEnabled: true
        ))
    }

    func testShouldScheduleSupplementAlertFalseWhenDisabled() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleSupplementAlert(
            scheduledFor: date(60),
            now: base,
            alertsEnabled: false
        ))
    }

    func testShouldScheduleSupplementAlertFalseWhenInPast() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleSupplementAlert(
            scheduledFor: date(-60),
            now: base,
            alertsEnabled: true
        ))
    }

    func testShouldScheduleSupplementAlertFalseWhenExactlyNow() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleSupplementAlert(
            scheduledFor: base,
            now: base,
            alertsEnabled: true
        ))
    }

    // MARK: - clampedReminderIntervalMinutes

    func testClampedReminderIntervalMinutesPassesThroughPositiveValues() {
        XCTAssertEqual(NotificationPolicy.clampedReminderIntervalMinutes(90), 90)
        XCTAssertEqual(NotificationPolicy.clampedReminderIntervalMinutes(1), 1)
    }

    func testClampedReminderIntervalMinutesClampsZeroAndNegative() {
        XCTAssertEqual(NotificationPolicy.clampedReminderIntervalMinutes(0), 1)
        XCTAssertEqual(NotificationPolicy.clampedReminderIntervalMinutes(-30), 1)
    }

    // MARK: - shouldScheduleReminders

    func testShouldScheduleRemindersTrueWhenEnabledAndLive() {
        XCTAssertTrue(NotificationPolicy.shouldScheduleReminders(isEnabled: true, isLive: true))
    }

    func testShouldScheduleRemindersFalseWhenDisabled() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleReminders(isEnabled: false, isLive: true))
    }

    func testShouldScheduleRemindersFalseWhenNotLive() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleReminders(isEnabled: true, isLive: false))
    }

    func testShouldScheduleRemindersFalseWhenBothFalse() {
        XCTAssertFalse(NotificationPolicy.shouldScheduleReminders(isEnabled: false, isLive: false))
    }
}
