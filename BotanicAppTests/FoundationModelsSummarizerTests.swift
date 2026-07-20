import BotanicKit
import Foundation
import Testing
@testable import Botanic

/// Prompt and output-contract regression tests. These deliberately do not invoke Foundation
/// Models: the journal remains on-device and the tests stay deterministic on CI and simulators.
struct FoundationModelsSummarizerTests {
    private let input = ExperienceSummaryInput(
        supplements: ["Magnesium glycinate", "Tea"],
        checkInWords: [["settled", "warm"], ["clear"]],
        valenceTrajectory: [0.58, 0.76],
        notes: ["The room was quiet", "A little more present"],
        startedAt: Date(timeIntervalSince1970: 1_752_944_400),
        duration: 3_600,
        calendar: Calendar(identifier: .gregorian)
    )

    @Test func promptKeepsTheIos27ContractAndChronology() {
        let prompt = OnDeviceExperienceSummarizer.prompt(for: input)

        #expect(prompt.contains("Prompt version: botanic-summary-ios27-v1"))
        #expect(OnDeviceExperienceSummarizer.instructions.contains("private, on-device"))
        #expect(OnDeviceExperienceSummarizer.instructions.contains("Never give advice"))
        #expect(prompt.contains("Supplements, in order taken: Magnesium glycinate, Tea"))
        #expect(prompt.contains("Check-in words, chronological: check-in 1: settled, warm; check-in 2: clear"))
        #expect(prompt.contains("Freeform notes, chronological: The room was quiet | A little more present"))
    }

    @Test func localEvaluatorAcceptsDescriptiveDrafts() {
        let output = ExperienceSummaryOutput(
            title: "A quiet evening together",
            subtitle: "The notes moved from warm to clear as the experience settled."
        )

        #expect(OnDeviceExperienceSummarizer.isAcceptable(output: output))
    }

    @Test func localEvaluatorRejectsPrescriptiveOrMalformedDrafts() {
        let advice = ExperienceSummaryOutput(
            title: "A steadier evening",
            subtitle: "You should take more next time for a stronger result."
        )
        let malformed = ExperienceSummaryOutput(title: "Too short", subtitle: "")

        #expect(!OnDeviceExperienceSummarizer.isAcceptable(output: advice))
        #expect(!OnDeviceExperienceSummarizer.isAcceptable(output: malformed))
    }
}
