import BotanicKit
import Foundation
import OSLog
import Sentry
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

    init() {}

    /// Seeds a draft from a remembered library entry — used by the Today "Again tonight?" quick-add
    /// and the Add sheet's recents chips, both of which prefill name/amount/intention from a past log.
    init(prefillingFrom item: SupplementLibraryItem) {
        self.name = item.name
        self.howTaking = item.lastAmount ?? ""
        self.intention = item.lastIntention ?? ""
    }
}

struct CheckInDraft {
    var valence: Double = 0.7
    var intensity: Double = 0.38
    var bodyLoad: Double = 0.28
    var feeling: FeelingWord = .settled
    // "Grounded" was part of the old flat PresenceTag vocabulary and isn't a member of any
    // PresenceGroup word set (body/mind/heart) — default to no pre-selected tags instead of
    // seeding a word the new UI can't display or toggle.
    var tags: Set<String> = []
    var note: String = ""
}

/// Thin action layer over the model context. Reads happen with `@Query` in views; these helpers
/// perform the writes (and the "first supplement starts an experience" rule).
///
/// Side effects (Live Activity updates, local notification scheduling, markdown mirroring) are
/// injected via narrow protocols (see `ExperienceStoreDependencies.swift`) so this type can be
/// exercised in unit tests without ActivityKit/UserNotifications/FileManager. `ExperienceStore.live`
/// is the shared production instance views call into.
@MainActor
struct ExperienceStore {
    private static let logger = Logger(subsystem: "com.botanic.app", category: "ExperienceStore")

    /// The shared production instance — wired to the real Live Activity, notification, and
    /// markdown mirror implementations. Views call `ExperienceStore.live.addSupplement(...)` etc.
    static let live = ExperienceStore()

    var liveActivity: any LiveActivityUpdating
    var notifications: any NotificationScheduling
    var markdownMirror: any MarkdownMirroring

    init(
        liveActivity: (any LiveActivityUpdating)? = nil,
        notifications: (any NotificationScheduling)? = nil,
        markdownMirror: (any MarkdownMirroring)? = nil
    ) {
        self.liveActivity = liveActivity ?? LiveActivityController.shared
        self.notifications = notifications ?? LiveNotificationScheduler()
        self.markdownMirror = markdownMirror ?? LiveMarkdownMirror()
    }

    /// The single live experience, if any.
    func liveExperience(in context: ModelContext) -> Experience? {
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
    func addSupplement(_ draft: SupplementDraft, in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Experience {
        let experience = liveExperience(in: context) ?? startExperience(in: context, now: now, calendar: calendar)

        let scheduled = draft.scheduleForLater
        let entry = SupplementEntry(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            howTaking: Self.cleaned(draft.howTaking),
            intention: Self.cleaned(draft.intention),
            takenAt: scheduled ? nil : now,
            scheduledFor: scheduled ? draft.scheduledFor : nil,
            status: scheduled ? .scheduled : .taken,
            colorIndex: experience.supplements.count
        )
        entry.experience = experience
        context.insert(entry)
        updateLibrary(for: entry.name, draft: draft, at: entry.effectiveTime, in: context)
        Self.save(context)
        syncLiveActivity(for: experience)
        if scheduled, let scheduledFor = entry.scheduledFor {
            notifications.scheduleSupplementAlert(id: entry.id, name: entry.name, at: scheduledFor)
        }
        notifications.rescheduleQuietSuggestion(lastEventAt: now)
        return experience
    }

    /// Upserts the remembered-supplement library entry so future logging can prefill the last
    /// amount and intention used for this supplement. Matches by trimmed, case-insensitive name.
    private func updateLibrary(for name: String, draft: SupplementDraft, at loggedAt: Date, in context: ModelContext) {
        let descriptor = FetchDescriptor<SupplementLibraryItem>()
        let existing = (try? context.fetch(descriptor))?.first {
            $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }

        if let item = existing {
            item.lastAmount = Self.cleaned(draft.howTaking)
            item.lastIntention = Self.cleaned(draft.intention)
            item.useCount += 1
            item.lastUsedAt = loggedAt
        } else {
            let item = SupplementLibraryItem(
                name: name,
                lastAmount: Self.cleaned(draft.howTaking),
                lastIntention: Self.cleaned(draft.intention),
                useCount: 1,
                lastUsedAt: loggedAt
            )
            context.insert(item)
        }
    }

    func startExperience(in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Experience {
        let experience = Experience(title: Self.defaultTitle(for: now, calendar: calendar), startedAt: now)
        context.insert(experience)
        notifications.scheduleRemindersIfEnabled()
        notifications.rescheduleQuietSuggestion(lastEventAt: now)
        return experience
    }

    func addCheckIn(_ draft: CheckInDraft, to experience: Experience, in context: ModelContext, now: Date = Date()) {
        let checkIn = CheckIn(
            createdAt: now,
            valence: draft.valence,
            intensity: draft.intensity,
            bodyLoad: draft.bodyLoad,
            feeling: draft.feeling,
            tags: Array(draft.tags).sorted(),
            note: Self.cleaned(draft.note)
        )
        checkIn.experience = experience
        context.insert(checkIn)
        Self.save(context)
        liveActivity.update(Self.liveState(for: experience))
        notifications.rescheduleQuietSuggestion(lastEventAt: now)
    }

    func addJournalEntry(text: String, kind: JournalKind, prompt: String?,
                          to experience: Experience, in context: ModelContext, now: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = JournalEntry(createdAt: now, kind: kind, text: trimmed, prompt: prompt)
        entry.experience = experience
        context.insert(entry)
        Self.save(context)
        liveActivity.update(Self.liveState(for: experience))
        notifications.rescheduleQuietSuggestion(lastEventAt: now)
    }

    /// Pure mapping from a live experience to the framework-free input the on-device summarizer
    /// consumes. Called while the experience is still live — the completion screen generates a
    /// preview from this before the user commits by ending the experience.
    func summaryInput(for experience: Experience, asOf now: Date = Date()) -> ExperienceSummaryInput {
        let checkIns = experience.checkIns.sorted { $0.createdAt < $1.createdAt }
        let notes = experience.journalEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.text)
        return ExperienceSummaryInput(
            supplements: experience.loggedSupplements.map(\.name),
            checkInWords: checkIns.map(\.tags),
            valenceTrajectory: checkIns.map(\.valence),
            notes: notes,
            startedAt: experience.startedAt,
            duration: experience.duration(asOf: now)
        )
    }

    /// Closes the experience with the user-approved title/subtitle/felt-words from the completion
    /// screen. `endedAt` is set first so the duration used elsewhere is final before the rest of the
    /// summary is applied.
    func end(
        _ experience: Experience,
        title: String,
        subtitle: String?,
        titleSource: TitleSource,
        feltWords: [String],
        in context: ModelContext,
        now: Date = Date()
    ) {
        experience.endedAt = now
        experience.title = title
        experience.subtitle = Self.cleaned(subtitle ?? "")
        experience.titleSource = titleSource
        experience.feltWords = feltWords
        if let firstWord = feltWords.first {
            experience.feltSummary = FeelingWord.allCases.first {
                $0.rawValue.lowercased() == firstWord.lowercased()
            } ?? experience.feltSummary ?? .settled
        }
        Self.save(context)
        liveActivity.end(Self.liveState(for: experience))
        notifications.cancelReminders()
        notifications.cancelQuietSuggestion()
        for entry in experience.scheduledSupplements {
            notifications.cancelSupplementAlert(id: entry.id)
        }
        markdownMirror.sync(experience, in: context)
    }

    /// Permanently removes an experience and its cascaded supplements, check-ins, and journal entries.
    func delete(_ experience: Experience, in context: ModelContext) {
        for entry in experience.scheduledSupplements {
            notifications.cancelSupplementAlert(id: entry.id)
        }
        context.delete(experience)
        Self.save(context)
    }

    /// Renames an experience from History's swipe action or the detail screen's title edit. Marks
    /// the title as user-authored so it's never silently overwritten by a future on-device draft.
    func rename(_ experience: Experience, to title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        experience.title = trimmed
        experience.titleSource = .user
        Self.save(context)
        markdownMirror.sync(experience, in: context)
    }

    /// Commits an edit to an experience's title and/or subtitle from the detail screen. Either value
    /// may be left unchanged by passing the experience's current value. Marks the title as
    /// user-authored, matching `rename(_:to:in:)`.
    func updateSummary(_ experience: Experience, title: String, subtitle: String?, in context: ModelContext) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            experience.title = trimmedTitle
            experience.titleSource = .user
        }
        experience.subtitle = Self.cleaned(subtitle ?? "")
        Self.save(context)
        markdownMirror.sync(experience, in: context)
    }

    /// Updates the amount/time on a single supplement entry from the detail screen's inline edit.
    func updateSupplement(_ entry: SupplementEntry, howTaking: String, takenAt: Date, in context: ModelContext) {
        entry.howTaking = Self.cleaned(howTaking)
        entry.takenAt = takenAt
        Self.save(context)
        if let experience = entry.experience {
            markdownMirror.sync(experience, in: context)
        }
    }

    /// Sets or clears the "note to future me" from the detail screen's inline edit. An empty string
    /// clears the note (stored as `nil`).
    func updateNoteToFuture(_ experience: Experience, note: String, in context: ModelContext) {
        experience.noteToFuture = Self.cleaned(note)
        Self.save(context)
        markdownMirror.sync(experience, in: context)
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

    // MARK: - Live Activity bridge

    /// Ensures a Live Activity is running for an experience that's still live at launch — after first
    /// re-attaching to any activity from a previous run (`adopt`), this re-creates one if none
    /// survived (force-quit, expiry). Safe to call repeatedly; `start` updates rather than duplicates.
    func resumeLiveActivity(for experience: Experience) {
        syncLiveActivity(for: experience)
    }

    /// Starts (or refreshes) the Live Activity for a live experience. Closed experiences are a no-op.
    private func syncLiveActivity(for experience: Experience) {
        guard experience.isLive else { return }
        liveActivity.start(experienceID: experience.id, state: Self.liveState(for: experience))
    }

    /// Maps a SwiftData `Experience` to the framework-free `ContentState` the widget renders —
    /// mirroring the `snapshots(from:)` / `timelineEntries(for:)` bridges (no SwiftData in the package).
    private static func liveState(for experience: Experience) -> BotanicActivityAttributes.ContentState {
        .init(
            startedAt: experience.startedAt,
            endedAt: experience.endedAt,
            title: experience.title,
            supplementCount: experience.loggedSupplements.count,
            checkInCount: experience.checkIns.count,
            latestSupplement: experience.loggedSupplements.last?.name
        )
    }

    // MARK: - Helpers

    private static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultTitle(for date: Date, calendar: Calendar = .current) -> String {
        TimeOfDay.defaultExperienceTitle(for: date, calendar: calendar)
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            // SwiftData autosaves; explicit save is best-effort, but a failure here is worth
            // knowing about — log locally and report to Sentry rather than swallowing silently.
            logger.error("Failed to save model context: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
}
