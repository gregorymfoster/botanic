import Foundation

/// Framework-free input for generating an end-of-experience title and subtitle.
public struct ExperienceSummaryInput: Sendable {
    /// Supplements taken, in the order they were logged.
    public let supplements: [String]
    /// The "What's present?" chips picked at each check-in, chronological, one array per check-in.
    public let checkInWords: [[String]]
    /// The valence slider value (0…1) recorded at each check-in, chronological.
    public let valenceTrajectory: [Double]
    /// Freeform journal notes, chronological.
    public let notes: [String]
    public let startedAt: Date
    public let duration: TimeInterval
    public let calendar: Calendar

    public init(
        supplements: [String],
        checkInWords: [[String]],
        valenceTrajectory: [Double],
        notes: [String],
        startedAt: Date,
        duration: TimeInterval,
        calendar: Calendar = .current
    ) {
        self.supplements = supplements
        self.checkInWords = checkInWords
        self.valenceTrajectory = valenceTrajectory
        self.notes = notes
        self.startedAt = startedAt
        self.duration = duration
        self.calendar = calendar
    }
}

/// A generated end-of-experience recap.
public struct ExperienceSummaryOutput: Equatable, Sendable {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
}

/// Produces an end-of-experience title and subtitle from an `ExperienceSummaryInput`. Conforming
/// types may call out to an AI service; `DeterministicExperienceSummarizer` is the offline,
/// always-available fallback.
public protocol ExperienceSummarizing: Sendable {
    func summarize(_ input: ExperienceSummaryInput) async throws -> ExperienceSummaryOutput
}

/// Builds an end-of-experience title and subtitle from templates, with no network calls and no
/// randomness — the same input always produces the same output.
public struct DeterministicExperienceSummarizer: ExperienceSummarizing {
    public init() {}

    public func summarize(_ input: ExperienceSummaryInput) async throws -> ExperienceSummaryOutput {
        Self.summarize(input)
    }

    /// The synchronous, pure core of the summarizer — exposed as a static function so callers who
    /// don't need the async protocol (e.g. previews, tests) can call it directly.
    public static func summarize(_ input: ExperienceSummaryInput) -> ExperienceSummaryOutput {
        let timeOfDay = timeOfDayWord(for: input.startedAt, calendar: input.calendar)
        let trajectory = Trajectory.classify(input.valenceTrajectory)
        let title = title(timeOfDay: timeOfDay, trajectory: trajectory, input: input)
        let subtitle = subtitle(trajectory: trajectory, input: input)
        return ExperienceSummaryOutput(title: title, subtitle: subtitle)
    }

    // MARK: - Time of day

    private static func timeOfDayWord(for date: Date, calendar: Calendar) -> String {
        TimeOfDay(date: date, calendar: calendar).summaryWord
    }

    // MARK: - Trajectory

    private enum Trajectory {
        case settled      // ended notably higher than it started, after a dip or plain rise
        case staySteady   // stayed roughly flat and pleasant throughout
        case brightened   // rose steadily
        case flat         // fewer than two points, or no meaningful change

        static func classify(_ valence: [Double]) -> Trajectory {
            guard let first = valence.first, let last = valence.last, valence.count >= 2 else {
                return .flat
            }
            let delta = last - first
            if delta > 0.15 {
                // Did it dip below the start before recovering? That reads as "finally settled".
                let minMid = valence.dropFirst().dropLast().min() ?? first
                if minMid < first - 0.05 {
                    return .settled
                }
                return .brightened
            }
            if abs(delta) <= 0.15 && first >= 0.55 {
                return .staySteady
            }
            return .flat
        }
    }

    // MARK: - Title

    private static func title(
        timeOfDay: String,
        trajectory: Trajectory,
        input: ExperienceSummaryInput
    ) -> String {
        let leadSupplement = input.supplements.first

        switch trajectory {
        case .settled:
            return "A slow \(timeOfDay) that finally settled"
        case .staySteady:
            if let s = leadSupplement {
                return "A quiet \(timeOfDay) with \(s)"
            }
            return "An easy \(timeOfDay) that stayed light"
        case .brightened:
            return "A \(timeOfDay) that got brighter"
        case .flat:
            if let s = leadSupplement {
                return "A \(timeOfDay) with \(s)"
            }
            return "A \(timeOfDay) worth remembering"
        }
    }

    // MARK: - Subtitle

    private static func subtitle(trajectory: Trajectory, input: ExperienceSummaryInput) -> String {
        var sentences: [String] = []

        if let supplementSentence = supplementSentence(input.supplements) {
            sentences.append(supplementSentence)
        }

        if let arcSentence = wordArcSentence(trajectory: trajectory, checkInWords: input.checkInWords) {
            sentences.append(arcSentence)
        }

        if let noteFragment = lastNoteFragment(input.notes) {
            sentences.append("\(noteFragment) was the turn.")
        }

        if sentences.isEmpty {
            sentences.append("A short check-in with nothing else logged.")
        }

        return sentences.joined(separator: " ")
    }

    private static func supplementSentence(_ supplements: [String]) -> String? {
        guard !supplements.isEmpty else { return nil }
        if supplements.count == 1 {
            return "\(supplements[0])."
        }
        let allButLast = supplements.dropLast().joined(separator: ", ")
        return "\(allButLast) then \(supplements.last!)."
    }

    private static func wordArcSentence(trajectory: Trajectory, checkInWords: [[String]]) -> String? {
        let nonEmpty = checkInWords.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return nil }

        let mid = nonEmpty.count / 2
        let earlyWords = FeltWordSummary.top(from: Array(nonEmpty.prefix(max(mid, 1))), limit: 1)
        let lateWords = FeltWordSummary.top(from: Array(nonEmpty.suffix(nonEmpty.count - mid)), limit: 1)

        guard let early = earlyWords.first?.lowercased() else { return nil }
        guard let late = lateWords.first?.lowercased(), nonEmpty.count > 1 else {
            return "\(early.capitalized) throughout."
        }

        if early == late {
            return "\(early.capitalized) throughout."
        }
        return "\(early.capitalized) early on, \(late) by the second check-in."
    }

    /// Extracts a short quoted fragment (its leading two words, e.g. "The tea") from the last note, so
    /// the subtitle can read "{fragment} was the turn." Capped at ~60 characters at a word boundary,
    /// with trailing punctuation stripped.
    private static func lastNoteFragment(_ notes: [String]) -> String? {
        guard let raw = notes.last?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let punctuation = CharacterSet(charactersIn: ".,!?;:")
        let words = raw
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: punctuation) }
            .filter { !$0.isEmpty }
        let leadingWordCount = min(2, words.count)
        var fragment = words.prefix(leadingWordCount).joined(separator: " ")

        let maxLength = 60
        if fragment.count > maxLength {
            var truncated = ""
            for word in fragment.split(separator: " ") {
                let candidate = truncated.isEmpty ? String(word) : "\(truncated) \(word)"
                if candidate.count > maxLength { break }
                truncated = candidate
            }
            fragment = truncated.isEmpty ? String(fragment.prefix(maxLength)) : truncated
        }

        guard !fragment.isEmpty else { return nil }
        return capitalizedFragment(fragment)
    }

    private static func capitalizedFragment(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
