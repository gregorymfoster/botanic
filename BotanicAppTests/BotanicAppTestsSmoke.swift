import Testing
@testable import Botanic

/// Placeholder smoke test so the BotanicAppTests bundle isn't empty. Exercises real app code
/// (constructing an `Experience` model) rather than a no-op assertion.
struct BotanicAppTestsSmoke {
    @Test func experienceDefaultsToUserTitledEveningAtHome() {
        let experience = Experience()
        #expect(experience.title == "Evening at home")
        #expect(experience.endedAt == nil)
    }
}
