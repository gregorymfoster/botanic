import ActivityKit
import AppIntents
import Foundation

/// A quick, glanceable check-in from the Live Activity. It records the app's neutral "settled"
/// default; richer sliders and optional notes remain in the full check-in sheet.
struct CheckInLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Check In"
    static let description = IntentDescription("Record a quick settled check-in for the live experience.")

    @Parameter(title: "Experience ID")
    var experienceID: String

    init() {
        experienceID = ""
    }

    init(experienceID: UUID) {
        self.experienceID = experienceID.uuidString
    }

    /// iOS 27's explicit target prevents the shared intent definition from ever writing SwiftData
    /// from the widget extension. The LiveActivityIntent protocol also targets the app process on
    /// earlier supported OS versions.
#if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
#endif

    func perform() async throws -> some IntentResult {
        #if BOTANIC_APP_TARGET
        let didApply = await BotanicLiveActivityIntentStore.checkIn(experienceID: experienceID)
        return .result(dialog: didApply ? "Checked in" : "No live experience")
        #else
        // The widget copy exists only so its archived Button(intent:) can resolve the type. The
        // explicit main-app execution target means this branch is never the writer.
        return .result()
        #endif
    }
}

/// Ends without opening the completion sheet. The current title and subtitle are preserved; a
/// person who wants the on-device drafted recap can still use the app's normal End flow.
struct EndLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Experience"
    static let description = IntentDescription("End the current Botanic experience immediately.")

    @Parameter(title: "Experience ID")
    var experienceID: String

    init() {
        experienceID = ""
    }

    init(experienceID: UUID) {
        self.experienceID = experienceID.uuidString
    }

#if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
#endif

    func perform() async throws -> some IntentResult {
        #if BOTANIC_APP_TARGET
        let didApply = await BotanicLiveActivityIntentStore.end(experienceID: experienceID)
        return .result(dialog: didApply ? "Experience ended" : "No live experience")
        #else
        return .result()
        #endif
    }
}

#if BOTANIC_APP_TARGET
import SwiftData

/// Main-app-only bridge used by LiveActivityIntent. Keeping SwiftData and app services behind the
/// app compilation condition prevents the widget extension from accidentally opening the store.
@MainActor
enum BotanicLiveActivityIntentStore {
    static func checkIn(experienceID rawID: String) -> Bool {
        guard let id = UUID(uuidString: rawID) else { return false }
        let context = ModelContext(BotanicModelContainer.shared)
        guard let experience = liveExperience(for: id, in: context) else { return false }
        ExperienceStore.live.addCheckIn(CheckInDraft(), to: experience, in: context)
        return true
    }

    static func end(experienceID rawID: String) -> Bool {
        guard let id = UUID(uuidString: rawID) else { return false }
        let context = ModelContext(BotanicModelContainer.shared)
        guard let experience = liveExperience(for: id, in: context) else { return false }
        ExperienceStore.live.end(
            experience,
            title: experience.title,
            subtitle: experience.subtitle,
            titleSource: experience.titleSource,
            feltWords: experience.feltWords,
            in: context
        )
        return true
    }

    private static func liveExperience(for id: UUID, in context: ModelContext) -> Experience? {
        var descriptor = FetchDescriptor<Experience>(predicate: #Predicate { experience in
            experience.id == id && experience.endedAt == nil
        })
        descriptor.fetchLimit = 1
        guard let experiences = try? context.fetch(descriptor) else { return nil }
        return experiences.first
    }
}
#endif
