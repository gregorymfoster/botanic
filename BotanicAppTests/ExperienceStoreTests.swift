import BotanicKit
import Foundation
import SwiftData
import Testing
@testable import Botanic

// MARK: - Mocks

/// Records every call so tests can assert on the exact sequence and arguments `ExperienceStore`
/// used, rather than just "some side effect happened."
@MainActor
final class MockLiveActivityController: LiveActivityUpdating {
    var startCalls: [(experienceID: UUID, state: BotanicActivityAttributes.ContentState)] = []
    var updateCalls: [BotanicActivityAttributes.ContentState] = []
    var endCalls: [BotanicActivityAttributes.ContentState] = []
    var adoptCalls: [UUID?] = []

    func start(experienceID: UUID, state: BotanicActivityAttributes.ContentState) {
        startCalls.append((experienceID, state))
    }

    func update(_ state: BotanicActivityAttributes.ContentState) {
        updateCalls.append(state)
    }

    func end(_ state: BotanicActivityAttributes.ContentState) {
        endCalls.append(state)
    }

    func adopt(liveExperienceID: UUID?) {
        adoptCalls.append(liveExperienceID)
    }
}

@MainActor
final class MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduledSupplementAlerts: [(id: UUID, name: String, date: Date)] = []
    private(set) var rescheduleQuietSuggestionCalls: [Date] = []
    private(set) var scheduleRemindersIfEnabledCallCount = 0
    private(set) var cancelRemindersCallCount = 0
    private(set) var cancelQuietSuggestionCallCount = 0
    private(set) var canceledSupplementAlertIDs: [UUID] = []

    func scheduleSupplementAlert(id: UUID, name: String, at date: Date) {
        scheduledSupplementAlerts.append((id, name, date))
    }

    func rescheduleQuietSuggestion(lastEventAt: Date) {
        rescheduleQuietSuggestionCalls.append(lastEventAt)
    }

    func scheduleRemindersIfEnabled() {
        scheduleRemindersIfEnabledCallCount += 1
    }

    func cancelReminders() {
        cancelRemindersCallCount += 1
    }

    func cancelQuietSuggestion() {
        cancelQuietSuggestionCallCount += 1
    }

    func cancelSupplementAlert(id: UUID) {
        canceledSupplementAlertIDs.append(id)
    }
}

@MainActor
final class MockMarkdownMirror: MarkdownMirroring {
    var syncedExperienceIDs: [UUID] = []

    func sync(_ experience: Experience, in context: ModelContext) {
        syncedExperienceIDs.append(experience.id)
    }
}

// MARK: - Test support

@MainActor
struct ExperienceStoreTestHarness {
    let container: ModelContainer
    let context: ModelContext
    let liveActivity: MockLiveActivityController
    let notifications: MockNotificationScheduler
    let markdownMirror: MockMarkdownMirror
    let store: ExperienceStore

    init() {
        let schema = Schema([Experience.self, SupplementEntry.self, CheckIn.self, JournalEntry.self, SupplementLibraryItem.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        liveActivity = MockLiveActivityController()
        notifications = MockNotificationScheduler()
        markdownMirror = MockMarkdownMirror()
        store = ExperienceStore(liveActivity: liveActivity, notifications: notifications, markdownMirror: markdownMirror)
    }
}

private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z

// MARK: - Tests

@MainActor
struct ExperienceStoreTests {

    // MARK: addSupplement

    @Test func addingFirstSupplementStartsExperienceAndStartsLiveActivity() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Magnesium"
        draft.howTaking = "400mg"

        #expect(harness.store.liveExperience(in: harness.context) == nil)

        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)

        #expect(harness.store.liveExperience(in: harness.context)?.id == experience.id)
        #expect(experience.startedAt == fixedNow)
        #expect(experience.supplements.count == 1)
        #expect(experience.supplements.first?.name == "Magnesium")

        // Starting the experience schedules reminders/quiet-suggestion; logging the supplement
        // reschedules the quiet suggestion again.
        #expect(harness.notifications.scheduleRemindersIfEnabledCallCount == 1)
        #expect(harness.notifications.rescheduleQuietSuggestionCalls == [fixedNow, fixedNow])

        // The Live Activity should have been started (not just updated) for the new experience.
        #expect(harness.liveActivity.startCalls.count == 1)
        #expect(harness.liveActivity.startCalls.first?.experienceID == experience.id)
        #expect(harness.liveActivity.updateCalls.isEmpty)
    }

    @Test func addingSecondSupplementReusesLiveExperience() {
        let harness = ExperienceStoreTestHarness()
        var first = SupplementDraft()
        first.name = "Magnesium"
        let experience = harness.store.addSupplement(first, in: harness.context, now: fixedNow)

        var second = SupplementDraft()
        second.name = "L-Theanine"
        let secondResult = harness.store.addSupplement(second, in: harness.context, now: fixedNow.addingTimeInterval(60))

        #expect(secondResult.id == experience.id)
        #expect(experience.supplements.count == 2)
        // Only the first addSupplement call should have started a new experience/reminders.
        #expect(harness.notifications.scheduleRemindersIfEnabledCallCount == 1)
    }

    @Test func schedulingASupplementForLaterSchedulesAnAlert() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Melatonin"
        draft.scheduleForLater = true
        let scheduledFor = fixedNow.addingTimeInterval(1800)
        draft.scheduledFor = scheduledFor

        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        let entry = experience.supplements.first!

        #expect(harness.notifications.scheduledSupplementAlerts.count == 1)
        #expect(harness.notifications.scheduledSupplementAlerts.first?.id == entry.id)
        #expect(harness.notifications.scheduledSupplementAlerts.first?.name == "Melatonin")
        #expect(harness.notifications.scheduledSupplementAlerts.first?.date == scheduledFor)
        #expect(entry.status == .scheduled)
        #expect(entry.takenAt == nil)
    }

    // MARK: addCheckIn / addJournalEntry — live activity updates

    @Test func checkInUpdatesLiveActivityState() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Magnesium"
        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        harness.liveActivity.startCalls.removeAll() // isolate the check-in's effect

        var checkIn = CheckInDraft()
        checkIn.feeling = .luminous
        checkIn.note = "feeling good"
        harness.store.addCheckIn(checkIn, to: experience, in: harness.context, now: fixedNow.addingTimeInterval(300))

        #expect(experience.checkIns.count == 1)
        #expect(harness.liveActivity.updateCalls.count == 1)
        #expect(harness.liveActivity.updateCalls.first?.checkInCount == 1)
        #expect(harness.notifications.rescheduleQuietSuggestionCalls.last == fixedNow.addingTimeInterval(300))
    }

    @Test func journalEntryUpdatesLiveActivityState() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Magnesium"
        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        harness.liveActivity.updateCalls.removeAll()

        harness.store.addJournalEntry(
            text: "Quiet evening.", kind: .note, prompt: nil,
            to: experience, in: harness.context, now: fixedNow.addingTimeInterval(120)
        )

        #expect(experience.journalEntries.count == 1)
        #expect(harness.liveActivity.updateCalls.count == 1)
    }

    @Test func journalEntryWithBlankTextIsIgnored() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)
        harness.liveActivity.updateCalls.removeAll()

        harness.store.addJournalEntry(text: "   ", kind: .note, prompt: nil, to: experience, in: harness.context, now: fixedNow)

        #expect(experience.journalEntries.isEmpty)
        #expect(harness.liveActivity.updateCalls.isEmpty)
    }

    // MARK: end

    @Test func endingAnExperienceCancelsEverythingAndEndsLiveActivity() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Melatonin"
        draft.scheduleForLater = true
        draft.scheduledFor = fixedNow.addingTimeInterval(1800)
        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        let scheduledEntryID = experience.supplements.first!.id

        let endTime = fixedNow.addingTimeInterval(3600)
        harness.store.end(
            experience,
            title: "Quiet night in",
            subtitle: "Just magnesium and reading",
            titleSource: .ai,
            feltWords: ["settled", "warm"],
            in: harness.context,
            now: endTime
        )

        #expect(experience.endedAt == endTime)
        #expect(experience.title == "Quiet night in")
        #expect(experience.titleSource == .ai)
        #expect(experience.feltWords == ["settled", "warm"])
        #expect(experience.feltSummary == .settled)

        #expect(harness.liveActivity.endCalls.count == 1)
        #expect(harness.notifications.cancelRemindersCallCount == 1)
        #expect(harness.notifications.cancelQuietSuggestionCallCount == 1)
        #expect(harness.notifications.canceledSupplementAlertIDs == [scheduledEntryID])
        #expect(harness.markdownMirror.syncedExperienceIDs == [experience.id])
    }

    @Test func endingWithoutFeltWordsLeavesFeltSummaryUnchanged() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)

        harness.store.end(
            experience, title: "Evening", subtitle: nil, titleSource: .user,
            feltWords: [], in: harness.context, now: fixedNow.addingTimeInterval(60)
        )

        #expect(experience.feltSummary == nil)
    }

    // MARK: delete

    @Test func deletingAnExperienceCancelsScheduledAlertsAndRemovesIt() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Melatonin"
        draft.scheduleForLater = true
        draft.scheduledFor = fixedNow.addingTimeInterval(1800)
        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        let scheduledEntryID = experience.supplements.first!.id

        harness.store.delete(experience, in: harness.context)

        // delete(_:in:) does not itself call the markdown mirror — its contract is: cancel
        // scheduled-supplement alerts, then remove the experience from the context.
        #expect(harness.notifications.canceledSupplementAlertIDs == [scheduledEntryID])
        #expect(harness.markdownMirror.syncedExperienceIDs.isEmpty)

        let remaining = try? harness.context.fetch(FetchDescriptor<Experience>())
        #expect(remaining?.isEmpty == true)
    }

    // MARK: rename / updateSummary / updateNoteToFuture — markdown re-sync

    @Test func renamingAnExperienceResyncsMarkdownMirror() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)

        harness.store.rename(experience, to: "  New Title  ", in: harness.context)

        #expect(experience.title == "New Title")
        #expect(experience.titleSource == .user)
        #expect(harness.markdownMirror.syncedExperienceIDs == [experience.id])
    }

    @Test func renamingToBlankTitleIsIgnored() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)
        let originalTitle = experience.title

        harness.store.rename(experience, to: "   ", in: harness.context)

        #expect(experience.title == originalTitle)
        #expect(harness.markdownMirror.syncedExperienceIDs.isEmpty)
    }

    @Test func updateSummaryResyncsMarkdownMirror() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)

        harness.store.updateSummary(experience, title: "Updated", subtitle: "A calmer night", in: harness.context)

        #expect(experience.title == "Updated")
        #expect(experience.subtitle == "A calmer night")
        #expect(experience.titleSource == .user)
        #expect(harness.markdownMirror.syncedExperienceIDs == [experience.id])
    }

    @Test func updateNoteToFutureResyncsMarkdownMirror() {
        let harness = ExperienceStoreTestHarness()
        let experience = harness.store.startExperience(in: harness.context, now: fixedNow)

        harness.store.updateNoteToFuture(experience, note: "Try less next time", in: harness.context)

        #expect(experience.noteToFuture == "Try less next time")
        #expect(harness.markdownMirror.syncedExperienceIDs == [experience.id])

        harness.store.updateNoteToFuture(experience, note: "  ", in: harness.context)
        #expect(experience.noteToFuture == nil)
    }

    @Test func updateSupplementResyncsMarkdownMirrorWhenAttachedToExperience() {
        let harness = ExperienceStoreTestHarness()
        var draft = SupplementDraft()
        draft.name = "Magnesium"
        let experience = harness.store.addSupplement(draft, in: harness.context, now: fixedNow)
        let entry = experience.supplements.first!
        harness.markdownMirror.syncedExperienceIDs.removeAll()

        let newTime = fixedNow.addingTimeInterval(600)
        harness.store.updateSupplement(entry, howTaking: "800mg", takenAt: newTime, in: harness.context)

        #expect(entry.howTaking == "800mg")
        #expect(entry.takenAt == newTime)
        #expect(harness.markdownMirror.syncedExperienceIDs == [experience.id])
    }

    // MARK: snapshots(from:) — pure mapping

    @Test func snapshotsCleansOneWordEntriesAndMapsFeltSummary() {
        let harness = ExperienceStoreTestHarness()
        let experience = Experience(startedAt: fixedNow, endedAt: fixedNow.addingTimeInterval(3600))
        experience.feltSummaryRaw = FeelingWord.settled.rawValue
        let oneWord = JournalEntry(kind: .oneWord, text: " calm. ")
        oneWord.experience = experience
        experience.journalEntries = [oneWord]
        harness.context.insert(experience)

        let snapshots = ExperienceStore.snapshots(from: [experience])

        #expect(snapshots.count == 1)
        #expect(snapshots.first?.words.contains("calm") == true)
        #expect(snapshots.first?.words.contains(FeelingWord.settled.rawValue) == true)
        #expect(snapshots.first?.feeling == .settled)
    }

    @Test func snapshotsExcludesLiveExperiences() {
        let liveExperience = Experience(startedAt: fixedNow)
        let snapshots = ExperienceStore.snapshots(from: [liveExperience])
        #expect(snapshots.isEmpty)
    }
}
