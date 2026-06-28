import BotanicKit
import Foundation
import SwiftData

/// One "experience" — a stretch of time the user is journaling, started by logging the first
/// supplement and closed when they end it. While `endedAt` is nil the experience is live.
@Model
final class Experience {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var locationContext: String?
    /// Stored as `FeelingWord.rawValue`; bridged through `feltSummary`.
    var feltSummaryRaw: String?
    var noteToFuture: String?

    @Relationship(deleteRule: .cascade, inverse: \SupplementEntry.experience)
    var supplements: [SupplementEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \CheckIn.experience)
    var checkIns: [CheckIn] = []
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.experience)
    var journalEntries: [JournalEntry] = []

    init(
        id: UUID = UUID(),
        title: String = "Evening at home",
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        locationContext: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.locationContext = locationContext
    }

    var isLive: Bool { endedAt == nil }

    var feltSummary: FeelingWord? {
        get { feltSummaryRaw.flatMap(FeelingWord.init(rawValue:)) }
        set { feltSummaryRaw = newValue?.rawValue }
    }

    /// Elapsed time, using `endedAt` once closed or `now` while live.
    func duration(asOf now: Date = Date()) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    /// Supplements already taken (not future-scheduled), newest first for the live list.
    var loggedSupplements: [SupplementEntry] {
        supplements.filter { $0.status == .taken }.sorted { $0.effectiveTime < $1.effectiveTime }
    }

    var scheduledSupplements: [SupplementEntry] {
        supplements.filter { $0.status == .scheduled }.sorted { $0.effectiveTime < $1.effectiveTime }
    }
}

enum SupplementStatus: String, Codable {
    case taken
    case scheduled
}

/// A single supplement logged within an experience — taken now or scheduled for later.
@Model
final class SupplementEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var howTaking: String?
    var intention: String?
    var takenAt: Date?
    var scheduledFor: Date?
    var statusRaw: String
    /// Index into the app's supplement orb gradients, so each supplement keeps a stable color.
    var colorIndex: Int
    var experience: Experience?

    init(
        id: UUID = UUID(),
        name: String,
        howTaking: String? = nil,
        intention: String? = nil,
        takenAt: Date? = Date(),
        scheduledFor: Date? = nil,
        status: SupplementStatus = .taken,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.howTaking = howTaking
        self.intention = intention
        self.takenAt = takenAt
        self.scheduledFor = scheduledFor
        self.statusRaw = status.rawValue
        self.colorIndex = colorIndex
    }

    var status: SupplementStatus {
        get { SupplementStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    /// The time this entry sorts by: when taken, or when scheduled.
    var effectiveTime: Date {
        takenAt ?? scheduledFor ?? Date.distantFuture
    }
}

/// A point-in-time check-in: how the moment feels across three gentle scales, a one-word summary,
/// and any "what's present" tags.
@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// 0…1 unpleasant→pleasant.
    var valence: Double
    /// 0…1 intensity.
    var intensity: Double
    /// 0…1 body load.
    var bodyLoad: Double
    var feelingRaw: String?
    /// Tags stored as a newline-joined string; SwiftData faults on plain `[String]` attributes, so
    /// we bridge through `tags`.
    var tagsRaw: String
    var experience: Experience?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        valence: Double = 0.7,
        intensity: Double = 0.38,
        bodyLoad: Double = 0.28,
        feeling: FeelingWord? = .settled,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.valence = valence
        self.intensity = intensity
        self.bodyLoad = bodyLoad
        self.feelingRaw = feeling?.rawValue
        self.tagsRaw = tags.joined(separator: "\n")
    }

    var feeling: FeelingWord? {
        get { feelingRaw.flatMap(FeelingWord.init(rawValue:)) }
        set { feelingRaw = newValue?.rawValue }
    }

    var tags: [String] {
        get { tagsRaw.isEmpty ? [] : tagsRaw.components(separatedBy: "\n") }
        set { tagsRaw = newValue.joined(separator: "\n") }
    }
}

enum JournalKind: String, Codable {
    case note
    case oneWord
    case freeform
}

/// A written entry on the experience timeline — a quick note, a single word, or a freeform reply to
/// a prompt.
@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kindRaw: String
    var text: String
    var prompt: String?
    var experience: Experience?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: JournalKind = .note,
        text: String,
        prompt: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kindRaw = kind.rawValue
        self.text = text
        self.prompt = prompt
    }

    var kind: JournalKind {
        get { JournalKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}
