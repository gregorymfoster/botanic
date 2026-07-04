import Foundation
import UserNotifications

/// Local check-in reminders that fire only while an experience is live. Scheduling is driven by
/// experience lifecycle (`ExperienceStore` schedules on start, cancels on end) and by the Settings
/// toggle. Preferences live in `UserDefaults` under the same keys the SettingsView binds via
/// `@AppStorage`, so this manager reads them directly without a view.
@MainActor
enum NotificationManager {
    /// `@AppStorage` keys — keep in sync with `SettingsView`.
    static let enabledKey = "remindersEnabled"
    static let intervalKey = "reminderIntervalMinutes"
    static let supplementAlertsEnabledKey = "supplementAlertsEnabled"
    static let quietSuggestEnabledKey = "quietSuggestEnabled"
    static let quietSuggestHoursKey = "quietSuggestHours"

    private static let reminderID = "botanic.checkin.reminder"
    private static let quietSuggestID = "botanic.quiet"
    private static func supplementAlertID(_ id: UUID) -> String { "botanic.supplement.\(id.uuidString)" }

    /// Reminders default **on** at **90 minutes** (matches the SettingsView `@AppStorage` defaults).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var intervalMinutes: Int {
        let stored = UserDefaults.standard.object(forKey: intervalKey) as? Int
        return stored ?? 90
    }

    /// Scheduled-supplement alerts default **on**.
    static var supplementAlertsEnabled: Bool {
        UserDefaults.standard.object(forKey: supplementAlertsEnabledKey) as? Bool ?? true
    }

    /// Suggest-ending-after-quiet defaults **on** at a **3 hour** threshold.
    static var quietSuggestEnabled: Bool {
        UserDefaults.standard.object(forKey: quietSuggestEnabledKey) as? Bool ?? true
    }

    static var quietSuggestHours: Int {
        let stored = UserDefaults.standard.object(forKey: quietSuggestHoursKey) as? Int
        return stored ?? 3
    }

    // MARK: - Authorization

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Scheduling

    /// Schedules the repeating reminder when the user has reminders enabled. Requests authorization
    /// first so a freshly-enabled session prompts once. Call when an experience goes live.
    static func scheduleRemindersIfEnabled() {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in schedule() }
        }
    }

    /// Re-evaluates scheduling after a preference change. `isLive` gates it so reminders never fire
    /// outside an experience.
    static func refresh(isLive: Bool) {
        if isEnabled && isLive {
            scheduleRemindersIfEnabled()
        } else {
            cancelReminders()
        }
    }

    static func cancelReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    private static func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let content = UNMutableNotificationContent()
        content.title = "How are you feeling?"
        content.body = "Take a slow breath and check in with where you are."
        content.sound = .default

        let seconds = TimeInterval(max(1, intervalMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Scheduled-supplement alerts

    /// Schedules a one-shot alert for a supplement planned for later. Skips silently if the setting
    /// is off or `date` has already passed.
    static func scheduleSupplementAlert(id: UUID, name: String, at date: Date) {
        guard supplementAlertsEnabled, date > Date() else { return }
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
                    identifier: supplementAlertID(id), content: content, trigger: trigger
                )
                center.add(request)
            }
        }
    }

    static func cancelSupplementAlert(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [supplementAlertID(id)])
    }

    // MARK: - Suggest ending after quiet

    /// Reschedules the "still going?" suggestion relative to the latest activity in a live
    /// experience. Cancels any pending suggestion first so only the most recent activity counts.
    static func rescheduleQuietSuggestion(lastEventAt: Date) {
        cancelQuietSuggestion()
        guard quietSuggestEnabled else { return }
        let fireDate = lastEventAt.addingTimeInterval(TimeInterval(max(1, quietSuggestHours)) * 3600)
        guard fireDate > Date() else { return }

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
                    identifier: quietSuggestID, content: content, trigger: trigger
                )
                center.add(request)
            }
        }
    }

    static func cancelQuietSuggestion() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [quietSuggestID])
    }
}
