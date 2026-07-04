import Foundation

/// Pure "should this notification fire / when" decisions for `NotificationManager`, extracted so
/// they're testable without `UNUserNotificationCenter` or `UserDefaults`. Every function here takes
/// its inputs as plain values — no `Date()` defaults, no framework types — so the app target's
/// `NotificationManager` is left with only the UserDefaults reads and UN framework glue.
public enum NotificationPolicy {
    /// Computes the fire date for the "still going?" quiet-suggestion notification, or `nil` if it
    /// shouldn't be scheduled at all (feature disabled, or the computed fire date has already passed).
    ///
    /// - Parameters:
    ///   - lastEventAt: The most recent activity in the live experience (supplement/check-in/journal).
    ///   - quietSuggestHours: Hours of quiet after which to suggest ending. Clamped to a minimum of 1.
    ///   - isEnabled: Whether the "suggest ending after quiet" setting is on.
    ///   - now: The current date, used to discard fire dates that are already in the past.
    public static func quietSuggestionFireDate(
        lastEventAt: Date,
        quietSuggestHours: Int,
        isEnabled: Bool,
        now: Date
    ) -> Date? {
        guard isEnabled else { return nil }
        let fireDate = lastEventAt.addingTimeInterval(TimeInterval(max(1, quietSuggestHours)) * 3600)
        return fireDate > now ? fireDate : nil
    }

    /// Whether a scheduled-supplement alert should be scheduled: the setting must be on and the
    /// scheduled time must still be in the future relative to `now`.
    public static func shouldScheduleSupplementAlert(
        scheduledFor: Date,
        now: Date,
        alertsEnabled: Bool
    ) -> Bool {
        alertsEnabled && scheduledFor > now
    }

    /// Clamps a user-configured reminder interval (minutes) to a minimum of 1, matching the guard
    /// the original inline scheduling logic applied before building the repeating trigger.
    public static func clampedReminderIntervalMinutes(_ intervalMinutes: Int) -> Int {
        max(1, intervalMinutes)
    }

    /// Whether the repeating check-in reminder should be (re)scheduled: reminders must be enabled
    /// and an experience must currently be live. Mirrors `NotificationManager.refresh(isLive:)`.
    public static func shouldScheduleReminders(isEnabled: Bool, isLive: Bool) -> Bool {
        isEnabled && isLive
    }
}
