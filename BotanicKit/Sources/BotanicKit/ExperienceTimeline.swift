import Foundation

/// One moment on an experience's timeline — a supplement taken, a check-in, or a journal entry —
/// reduced to the framework-free fields the UI needs to render it. The app maps its SwiftData models
/// into these so the merge/sort/offset logic stays pure and testable (mirrors `ExperienceSnapshot`).
public struct TimelineEntry: Sendable, Hashable, Identifiable {
    /// What happened at this moment, carrying only its display text.
    public enum Kind: Sendable, Hashable {
        case supplement(name: String, howTaking: String?)
        case checkIn(word: String)
        case journal(text: String, isOneWord: Bool)
    }

    public let id: UUID
    public let date: Date
    /// Seconds elapsed from the experience's start — drives the "h:mm" offset label.
    public let offset: TimeInterval
    public let kind: Kind

    public init(id: UUID, date: Date, offset: TimeInterval, kind: Kind) {
        self.id = id
        self.date = date
        self.offset = offset
        self.kind = kind
    }
}

/// An unplaced moment handed to the builder — the same fields as `TimelineEntry` minus the `offset`,
/// which the builder computes from the experience start.
public struct TimelineInput: Sendable, Hashable {
    public let id: UUID
    public let date: Date
    public let kind: TimelineEntry.Kind

    public init(id: UUID, date: Date, kind: TimelineEntry.Kind) {
        self.id = id
        self.date = date
        self.kind = kind
    }
}

/// Builds the chronological timeline for a single experience. Pure and deterministic given its
/// inputs, so it can be unit-tested without SwiftData or a clock.
public enum ExperienceTimeline {
    /// Sorts the moments chronologically and stamps each with its offset from `start`. Ties break by
    /// `id` so output is stable regardless of input order. Offsets are clamped at zero.
    public static func build(_ inputs: [TimelineInput], start: Date) -> [TimelineEntry] {
        inputs
            .sorted { lhs, rhs in
                lhs.date != rhs.date ? lhs.date < rhs.date : lhs.id.uuidString < rhs.id.uuidString
            }
            .map { input in
                TimelineEntry(
                    id: input.id,
                    date: input.date,
                    offset: max(0, input.date.timeIntervalSince(start)),
                    kind: input.kind
                )
            }
    }
}
