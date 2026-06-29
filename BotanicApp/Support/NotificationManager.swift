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

    private static let reminderID = "botanic.checkin.reminder"

    /// Reminders default **on** at **90 minutes** (matches the SettingsView `@AppStorage` defaults).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var intervalMinutes: Int {
        let stored = UserDefaults.standard.object(forKey: intervalKey) as? Int
        return stored ?? 90
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
}
