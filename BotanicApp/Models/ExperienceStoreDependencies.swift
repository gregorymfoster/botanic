import ActivityKit
import BotanicKit
import Foundation
import SwiftData

/// Narrow seam over `LiveActivityController` so `ExperienceStore` can be exercised in unit tests
/// without touching ActivityKit. Method shapes mirror exactly what `ExperienceStore` calls.
@MainActor
protocol LiveActivityUpdating {
    func start(experienceID: UUID, state: BotanicActivityAttributes.ContentState)
    func update(_ state: BotanicActivityAttributes.ContentState)
    func end(_ state: BotanicActivityAttributes.ContentState)
    func adopt(liveExperienceID: UUID?)
}

extension LiveActivityController: LiveActivityUpdating {}

/// Narrow seam over `NotificationManager`'s scheduling calls so `ExperienceStore` can be tested
/// without touching `UNUserNotificationCenter`.
@MainActor
protocol NotificationScheduling {
    func scheduleSupplementAlert(id: UUID, name: String, at date: Date)
    func rescheduleQuietSuggestion(lastEventAt: Date)
    func scheduleRemindersIfEnabled()
    func cancelReminders()
    func cancelQuietSuggestion()
    func cancelSupplementAlert(id: UUID)
}

/// Production `NotificationScheduling` — thin wrapper over `NotificationManager`'s static funcs.
struct LiveNotificationScheduler: NotificationScheduling {
    func scheduleSupplementAlert(id: UUID, name: String, at date: Date) {
        NotificationManager.scheduleSupplementAlert(id: id, name: name, at: date)
    }

    func rescheduleQuietSuggestion(lastEventAt: Date) {
        NotificationManager.rescheduleQuietSuggestion(lastEventAt: lastEventAt)
    }

    func scheduleRemindersIfEnabled() {
        NotificationManager.scheduleRemindersIfEnabled()
    }

    func cancelReminders() {
        NotificationManager.cancelReminders()
    }

    func cancelQuietSuggestion() {
        NotificationManager.cancelQuietSuggestion()
    }

    func cancelSupplementAlert(id: UUID) {
        NotificationManager.cancelSupplementAlert(id: id)
    }
}

/// Narrow seam over `MarkdownMirrorService.sync` so `ExperienceStore` can be tested without
/// touching `FileManager`/`NSFileCoordinator`.
@MainActor
protocol MarkdownMirroring {
    func sync(_ experience: Experience, in context: ModelContext)
}

/// Production `MarkdownMirroring` — thin wrapper over `MarkdownMirrorService.sync`.
struct LiveMarkdownMirror: MarkdownMirroring {
    func sync(_ experience: Experience, in context: ModelContext) {
        MarkdownMirrorService.sync(experience, in: context)
    }
}
