import BotanicKit
import Foundation
import SwiftData

/// Value-type drafts edited by the sheets, then applied on save (mirrors Breathwork's
/// `SessionReflection` pattern — keep editing state out of the SwiftData models until commit).
struct SupplementDraft {
    var name: String = ""
    var howTaking: String = ""
    var intention: String = ""
    var scheduleForLater: Bool = false
    var scheduledFor: Date = Date().addingTimeInterval(30 * 60)

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct CheckInDraft {
    var valence: Double = 0.7
    var intensity: Double = 0.38
    var bodyLoad: Double = 0.28
    var feeling: FeelingWord = .settled
    var tags: Set<String> = ["Grounded", "Calm"]
}

struct ReflectionDraft {
    var feeling: FeelingWord = .settled
    var noteToFuture: String = ""
}

/// Thin action layer over the model context. Reads happen with `@Query` in views; these helpers
/// perform the writes (and the "first supplement starts an experience" rule).
@MainActor
enum ExperienceStore {
    /// The single live experience, if any.
    static func liveExperience(in context: ModelContext) -> Experience? {
        var descriptor = FetchDescriptor<Experience>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// The most recently started finished experience, if any. Used by the screenshot deep-link hook.
    static func mostRecentFinished(in context: ModelContext) -> Experience? {
        var descriptor = FetchDescriptor<Experience>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Adds a supplement. With no live experience, this starts one (the core "first supplement
    /// begins an experience" rule). Returns the experience the entry landed in.
    @discardableResult
    static func addSupplement(_ draft: SupplementDraft, in context: ModelContext, now: Date = Date()) -> Experience {
        let experience = liveExperience(in: context) ?? startExperience(in: context, now: now)

        let scheduled = draft.scheduleForLater
        let entry = SupplementEntry(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            howTaking: cleaned(draft.howTaking),
            intention: cleaned(draft.intention),
            takenAt: scheduled ? nil : now,
            scheduledFor: scheduled ? draft.scheduledFor : nil,
            status: scheduled ? .scheduled : .taken,
            colorIndex: experience.supplements.count
        )
        entry.experience = experience
        context.insert(entry)
        save(context)
        return experience
    }

    static func startExperience(in context: ModelContext, now: Date = Date()) -> Experience {
        let experience = Experience(title: defaultTitle(for: now), startedAt: now)
        context.insert(experience)
        return experience
    }

    static func addCheckIn(_ draft: CheckInDraft, to experience: Experience, in context: ModelContext, now: Date = Date()) {
        let checkIn = CheckIn(
            createdAt: now,
            valence: draft.valence,
            intensity: draft.intensity,
            bodyLoad: draft.bodyLoad,
            feeling: draft.feeling,
            tags: Array(draft.tags).sorted()
        )
        checkIn.experience = experience
        context.insert(checkIn)
        save(context)
    }

    static func addJournalEntry(text: String, kind: JournalKind, prompt: String?,
                                to experience: Experience, in context: ModelContext, now: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = JournalEntry(createdAt: now, kind: kind, text: trimmed, prompt: prompt)
        entry.experience = experience
        context.insert(entry)
        save(context)
    }

    /// Closes the experience and applies the end-of-experience reflection.
    static func end(_ experience: Experience, reflection: ReflectionDraft, in context: ModelContext, now: Date = Date()) {
        experience.endedAt = now
        experience.feltSummary = reflection.feeling
        experience.noteToFuture = cleaned(reflection.noteToFuture)
        save(context)
    }

    /// Permanently removes an experience and its cascaded supplements, check-ins, and journal entries.
    static func delete(_ experience: Experience, in context: ModelContext) {
        context.delete(experience)
        save(context)
    }

    // MARK: - Insights bridge

    /// Maps finished experiences to framework-free snapshots for `InsightsEngine`.
    static func snapshots(from experiences: [Experience]) -> [ExperienceSnapshot] {
        experiences.compactMap { exp in
            guard let endedAt = exp.endedAt else { return nil }
            let oneWordEntries = exp.journalEntries
                .filter { $0.kind == .oneWord }
                .map { $0.text.trimmingCharacters(in: CharacterSet(charactersIn: " .")) }
            var words = oneWordEntries
            if let felt = exp.feltSummary { words.append(felt.rawValue) }
            return ExperienceSnapshot(
                startedAt: exp.startedAt,
                endedAt: endedAt,
                feeling: exp.feltSummary,
                locationContext: exp.locationContext,
                supplementNames: exp.supplements.map(\.name),
                checkInCount: exp.checkIns.count,
                words: words
            )
        }
    }

    // MARK: - Timeline bridge

    /// Maps an experience's taken supplements, check-ins, and journal entries to framework-free
    /// `TimelineEntry` values, chronologically ordered with offsets from the start. Shared by the
    /// live Journal sheet and the read-only history detail view.
    static func timelineEntries(for experience: Experience) -> [TimelineEntry] {
        var inputs: [TimelineInput] = []
        for s in experience.supplements where s.status == .taken {
            inputs.append(TimelineInput(
                id: s.id,
                date: s.takenAt ?? experience.startedAt,
                kind: .supplement(name: s.name, howTaking: s.howTaking)
            ))
        }
        for c in experience.checkIns {
            inputs.append(TimelineInput(
                id: c.id,
                date: c.createdAt,
                kind: .checkIn(word: c.feeling?.rawValue ?? "Steady")
            ))
        }
        for j in experience.journalEntries {
            inputs.append(TimelineInput(
                id: j.id,
                date: j.createdAt,
                kind: .journal(text: j.text, isOneWord: j.kind == .oneWord)
            ))
        }
        return ExperienceTimeline.build(inputs, start: experience.startedAt)
    }

    // MARK: - Helpers

    private static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultTitle(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Slow morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening at home"
        default: return "Late night"
        }
    }

    private static func save(_ context: ModelContext) {
        do { try context.save() } catch { /* SwiftData autosaves; explicit save is best-effort */ }
    }
}
