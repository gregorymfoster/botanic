#if canImport(FoundationModels)
import FoundationModels
#endif
import BotanicKit
import Foundation

/// On-device end-of-experience title/subtitle generation using Apple's Foundation Models framework,
/// when it's importable and the system model is available. Always falls back to
/// `DeterministicExperienceSummarizer` on any error, unavailability, or unexpected output — callers
/// never see a thrown error or an empty result.
///
/// Output is always plain, editable text: the app marks it "drafted on-device" and lets the user
/// rewrite it freely (see `EndExperienceView`), so this type only needs to produce a reasonable
/// starting draft, not a final answer.
public struct OnDeviceExperienceSummarizer: ExperienceSummarizing {
    public init() {}

    public func summarize(_ input: ExperienceSummaryInput) async throws -> ExperienceSummaryOutput {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let output = try? await generate(input) {
            return output
        }
        #endif
        return DeterministicExperienceSummarizer.summarize(input)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generate(_ input: ExperienceSummaryInput) async throws -> ExperienceSummaryOutput? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.prompt(for: input)
        let response = try await session.respond(to: prompt, generating: DraftSummary.self)
        let title = response.content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = response.content.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !subtitle.isEmpty else { return nil }
        return ExperienceSummaryOutput(title: title, subtitle: subtitle)
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct DraftSummary {
        @Guide(description: "A short sentence-case title for the experience, 3-7 words, no trailing period. Quiet, private-journal tone — descriptive, never advice.")
        var title: String
        @Guide(description: "One or two sentences describing what happened, in a quiet private-journal tone. Never give advice, dosage commentary, or medical suggestions — descriptive only.")
        var subtitle: String
    }

    private static let instructions = """
    You help draft short titles and subtitles for entries in a private, on-device supplement and \
    wellness journal. The tone is that of a quiet, personal journal — warm, understated, and \
    observational. Never give advice, dosage commentary, or medical suggestions; only describe what \
    the person logged and how they said it felt. Titles are sentence-case, 3-7 words, and never end \
    with a period. Subtitles are one or two short sentences.
    """

    private static func prompt(for input: ExperienceSummaryInput) -> String {
        let timeOfDay = TimeOfDay(date: input.startedAt, calendar: input.calendar).summaryWord

        var lines: [String] = []
        lines.append("Time of day: \(timeOfDay)")
        lines.append("Duration: \(input.duration.botanicDuration)")
        if input.supplements.isEmpty {
            lines.append("Supplements: none logged")
        } else {
            lines.append("Supplements, in order taken: \(input.supplements.joined(separator: ", "))")
        }

        if input.checkInWords.isEmpty {
            lines.append("Check-ins: none")
        } else {
            let perCheckIn = input.checkInWords.enumerated().map { index, words -> String in
                words.isEmpty ? "check-in \(index + 1): no words selected" : "check-in \(index + 1): \(words.joined(separator: ", "))"
            }
            lines.append("Check-in words, chronological: \(perCheckIn.joined(separator: "; "))")
        }

        if input.valenceTrajectory.isEmpty {
            lines.append("Feeling trajectory: not recorded")
        } else {
            let described = input.valenceTrajectory.map(Self.valenceWord)
            lines.append("Feeling trajectory, chronological: \(described.joined(separator: " -> "))")
        }

        if !input.notes.isEmpty {
            lines.append("Freeform notes, chronological: \(input.notes.joined(separator: " | "))")
        }

        lines.append("Write a title and a one-to-two sentence subtitle describing this experience.")
        return lines.joined(separator: "\n")
    }

    private static func valenceWord(_ value: Double) -> String {
        switch value {
        case ..<0.3: return "unpleasant"
        case 0.3..<0.5: return "mixed"
        case 0.5..<0.7: return "settling"
        case 0.7..<0.85: return "pleasant"
        default: return "very pleasant"
        }
    }
    #endif
}
