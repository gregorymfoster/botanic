import BotanicKit
import Foundation
import UserNotifications

/// Local check-in reminders that fire only while an experience is live. Scheduling is driven by
/// experience lifecycle (`ExperienceStore` schedules on start, cancels on end) and by the Settings
/// toggle. Preferences live in `UserDefaults` under the same keys the SettingsView binds via
/// `@AppStorage`, so this manager reads them directly without a view.
///
/// All "should this fire / when" decisions are delegated to `NotificationPolicy` in BotanicKit —
/// this type only reads settings from its injected `UserDefaults` and drives
/// `UNUserNotificationCenter`. `NotificationManager.live` is the shared production instance;
/// `LiveNotificationScheduler` in `ExperienceStoreDependencies.swift` wraps it for `ExperienceStore`.
@MainActor
struct NotificationManager {
    /// `@AppStorage` keys — keep in sync with `SettingsView`.
    static let enabledKey = "remindersEnabled"
    static let intervalKey = "reminderIntervalMinutes"
    static let supplementAlertsEnabledKey = "supplementAlertsEnabled"
    static let quietSuggestEnabledKey = "quietSuggestEnabled"
    static let quietSuggestHoursKey = "quietSuggestHours"

    private static let reminderID = "botanic.checkin.reminder"
    private static let quietSuggestID = "botanic.quiet"
    private static func supplementAlertID(_ id: UUID) -> String { "botanic.supplement.\(id.uuidString)" }

    /// The shared production instance, backed by `UserDefaults.standard`.
    static let live = NotificationManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Reminders default **on** at **90 minutes** (matches the SettingsView `@AppStorage` defaults).
    var isEnabled: Bool {
        defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    var intervalMinutes: Int {
        let stored = defaults.object(forKey: Self.intervalKey) as? Int
        return stored ?? 90
    }

    /// Scheduled-supplement alerts default **on**.
    var supplementAlertsEnabled: Bool {
        defaults.object(forKey: Self.supplementAlertsEnabledKey) as? Bool ?? true
    }

    /// Suggest-ending-after-quiet defaults **on** at a **3 hour** threshold.
    var quietSuggestEnabled: Bool {
        defaults.object(forKey: Self.quietSuggestEnabledKey) as? Bool ?? true
    }

    var quietSuggestHours: Int {
        let stored = defaults.object(forKey: Self.quietSuggestHoursKey) as? Int
        return stored ?? 3
    }

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Scheduling

    /// Schedules the repeating reminder when the user has reminders enabled. Requests authorization
    /// first so a freshly-enabled session prompts once. Call when an experience goes live.
    func scheduleRemindersIfEnabled() {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in self.schedule() }
        }
    }

    /// Re-evaluates scheduling after a preference change. `isLive` gates it so reminders never fire
    /// outside an experience.
    func refresh(isLive: Bool) {
        if NotificationPolicy.shouldScheduleReminders(isEnabled: isEnabled, isLive: isLive) {
            scheduleRemindersIfEnabled()
        } else {
            cancelReminders()
        }
    }

    func cancelReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }

    private func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])

        let content = UNMutableNotificationContent()
        content.title = "How are you feeling?"
        content.body = "Take a slow breath and check in with where you are."
        content.sound = .default

        let seconds = TimeInterval(NotificationPolicy.clampedReminderIntervalMinutes(intervalMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Scheduled-supplement alerts

    /// Schedules a one-shot alert for a supplement planned for later. Skips silently if the setting
    /// is off or `date` has already passed.
    func scheduleSupplementAlert(id: UUID, name: String, at date: Date) {
        guard NotificationPolicy.shouldScheduleSupplementAlert(
            scheduledFor: date, now: Date(), alertsEnabled: supplementAlertsEnabled
        ) else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                let content = UNMutableNotificationContent()
                content.title = "A supplement you planned is due."
                content.body = "Scheduled: \(name)"
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: date
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: Self.supplementAlertID(id), content: content, trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func cancelSupplementAlert(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.supplementAlertID(id)])
    }

    // MARK: - Suggest ending after quiet

    /// Reschedules the "still going?" suggestion relative to the latest activity in a live
    /// experience. Cancels any pending suggestion first so only the most recent activity counts.
    func rescheduleQuietSuggestion(lastEventAt: Date) {
        cancelQuietSuggestion()
        guard let fireDate = NotificationPolicy.quietSuggestionFireDate(
            lastEventAt: lastEventAt,
            quietSuggestHours: quietSuggestHours,
            isEnabled: quietSuggestEnabled,
            now: Date()
        ) else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                let content = UNMutableNotificationContent()
                content.title = "Still going?"
                content.body = "If this experience has wound down, you can end it when you're ready."
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: Self.quietSuggestID, content: content, trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func cancelQuietSuggestion() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.quietSuggestID])
    }
}
