import ActivityKit
import BotanicKit
import Foundation

/// Owns the single `Activity<BotanicActivityAttributes>` that tracks a live experience on the lock
/// screen and Dynamic Island. `ExperienceStore` calls into this after each write — `start` when an
/// experience goes live, `update` as counts change, `end` when it closes. All entry points are safe
/// no-ops when Live Activities are unavailable or none is running, so callers needn't guard.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    private var activity: Activity<BotanicActivityAttributes>?

    /// Re-attach to an activity still running from a previous launch (e.g. the app was backgrounded
    /// while an experience stayed live). Matches on the experience id when one is provided.
    func adopt(liveExperienceID: UUID?) {
        guard activity == nil else { return }
        activity = Activity<BotanicActivityAttributes>.activities.first { running in
            liveExperienceID == nil || running.attributes.experienceID == liveExperienceID
        }
    }

    /// Starts the activity for an experience, or updates it if one is already running. Idempotent so
    /// the supplement-logging path can call it freely.
    func start(experienceID: UUID, state: BotanicActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { update(state); return }
        do {
            activity = try Activity.request(
                attributes: BotanicActivityAttributes(experienceID: experienceID),
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            // Requests can still fail (e.g. the system activity budget); fail quietly.
        }
    }

    func update(_ state: BotanicActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end(_ state: BotanicActivityAttributes.ContentState) {
        guard let activity else { return }
        let finishing = activity
        self.activity = nil
        Task { await finishing.end(.init(state: state, staleDate: nil), dismissalPolicy: .default) }
    }
}
