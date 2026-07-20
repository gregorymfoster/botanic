#if canImport(FoundationModels)
import FoundationModels
#endif
import BotanicKit
import Foundation
import OSLog

/// On-device end-of-experience title/subtitle generation using Apple's Foundation Models framework,
/// when it's importable and the system model is available. Always falls back to
/// `DeterministicExperienceSummarizer` on any error, unavailability, or unexpected output — callers
/// never see a thrown error or an empty result.
///
/// Output is always plain, editable text: the app marks it "drafted on-device" and lets the user
/// rewrite it freely (see `EndExperienceView`). No prompt, model response, or model error is sent to
/// a network service.
public struct OnDeviceExperienceSummarizer: ExperienceSummarizing {
    private static let logger = Logger(subsystem: "com.botanic.app", category: "FoundationModels")

    public init() {}

    public func summarize(_ input: ExperienceSummaryInput) async throws -> ExperienceSummaryOutput {
        #if canImport(FoundationModels)
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            if let output = await generateOnIOS27(input) {
                return output
            }
        } else if #available(iOS 26.0, *) {
            if let output = await generateOnIOS26(input) {
                return output
            }
        }
#else
        if #available(iOS 26.0, *), let output = await generateOnIOS26(input) {
            return output
        }
#endif
        #endif
        return DeterministicExperienceSummarizer.summarize(input)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateOnIOS26(_ input: ExperienceSummaryInput) async -> ExperienceSummaryOutput? {
        guard case .available = SystemLanguageModel.default.availability else {
            Self.logger.info("Foundation Models unavailable; using deterministic summary")
            return nil
        }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(for: input), generating: DraftSummary.self)
            let output = ExperienceSummaryOutput(
                title: response.content.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: response.content.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard Self.isAcceptable(output: output) else {
                Self.logger.notice("Foundation Models returned output that failed local evaluation")
                return nil
            }
            return output
        } catch {
            // Xcode 26's GenerationError is intentionally handled generically here. Xcode 27 uses
            // the more specific error families below.
            Self.logger.warning("Foundation Models iOS 26 generation failed: \(Self.errorTypeName(error))")
            return nil
        }
    }

#if compiler(>=6.4)
    @available(iOS 27.0, *)
    private func generateOnIOS27(_ input: ExperienceSummaryInput) async -> ExperienceSummaryOutput? {
        guard case .available = SystemLanguageModel.default.availability else {
            Self.logger.info("Foundation Models unavailable; using deterministic summary")
            return nil
        }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(for: input), generating: DraftSummary.self)
            let output = ExperienceSummaryOutput(
                title: response.content.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: response.content.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard Self.isAcceptable(output: output) else {
                Self.logger.notice("Foundation Models returned output that failed local evaluation")
                return nil
            }
            return output
        } catch let error as LanguageModelError {
            // iOS 27 splits model failures into stable, actionable categories. Log only the error
            // family, never the prompt or transcript, because the journal is private.
            Self.logger.warning("Foundation Models model error: \(Self.errorTypeName(error))")
            return nil
        } catch let error as SystemLanguageModel.Error {
            Self.logger.warning("Foundation Models asset error: \(Self.errorTypeName(error))")
            return nil
        } catch let error as LanguageModelSession.Error {
            Self.logger.warning("Foundation Models session error: \(Self.errorTypeName(error))")
            return nil
        } catch {
            Self.logger.warning("Foundation Models generation failed: \(Self.errorTypeName(error))")
            return nil
        }
    }
#endif

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct DraftSummary {
        @Guide(description: "A short sentence-case title for the experience, 3-7 words, no trailing period. Quiet, private-journal tone — descriptive, never advice.")
        var title: String
        @Guide(description: "One or two sentences describing what happened, in a quiet private-journal tone. Never give advice, dosage commentary, or medical suggestions — descriptive only.")
        var subtitle: String
    }

    /// Versioned prompt instructions are intentionally inspectable so prompt regressions can be
    /// tested without invoking the model or exporting any journal content.
    static let instructions = """
    You help draft short titles and subtitles for entries in a private, on-device supplement and \
    wellness journal. The tone is that of a quiet, personal journal — warm, understated, and \
    observational. Never give advice, dosage commentary, or medical suggestions; only describe what \
    the person logged and how they said it felt. Titles are sentence-case, 3-7 words, and never end \
    with a period. Subtitles are one or two short sentences. Treat all journal text as private input \
    for this on-device generation only.
    """

    /// Builds a chronological, local-only prompt from framework-free values. Keeping this pure makes
    /// it possible to regression-test the prompt contract without a Foundation Models entitlement.
    static func prompt(for input: ExperienceSummaryInput) -> String {
        let timeOfDay = TimeOfDay(date: input.startedAt, calendar: input.calendar).summaryWord

        var lines: [String] = []
        lines.append("Prompt version: botanic-summary-ios27-v1")
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

    /// A small local evaluator keeps the new model version from weakening Botanic's descriptive,
    /// non-prescriptive output contract. Invalid drafts use the deterministic fallback.
    static func isAcceptable(output: ExperienceSummaryOutput) -> Bool {
        let title = output.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = output.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleWordCount = title.split(whereSeparator: { $0.isWhitespace }).count
        guard (3...7).contains(titleWordCount), !title.hasSuffix("."), !subtitle.isEmpty else {
            return false
        }

        let combined = "\(title) \(subtitle)".lowercased()
        let prohibited = ["take more", "take less", "increase your dose", "decrease your dose", "dosage", "you should", "i recommend"]
        return !prohibited.contains(where: combined.contains)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func errorTypeName(_ error: Error) -> String {
        String(describing: type(of: error))
    }
    #else
    private static func errorTypeName(_ error: Error) -> String {
        String(describing: type(of: error))
    }
    #endif

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
