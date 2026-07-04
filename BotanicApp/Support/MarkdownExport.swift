import BotanicKit
import Foundation

/// Renders an experience to a portable, user-readable Markdown document — the "export as Markdown"
/// affordance and the on-device mirror file written by `MarkdownMirrorService`. Private and
/// user-authored: it's the user's own notes, nothing more. A pure string builder so it can be reused
/// for the detail Share, Settings export-all, the folder mirror, and the zip export.
enum MarkdownExport {
    static func experience(_ exp: Experience) -> String {
        var lines: [String] = []
        lines.append("# \(exp.title)")
        lines.append("")

        if let subtitle = exp.subtitle, !subtitle.isEmpty {
            lines.append("_\(subtitle)_")
            lines.append("")
        }

        lines.append("| | |")
        lines.append("|---|---|")
        lines.append("| Date | \(BotanicFormat.shortDate(exp.startedAt, includeYear: true)) |")
        lines.append("| Duration | \(exp.duration().botanicDuration) |")
        let feltWords = exp.feltWords.isEmpty ? (exp.feltSummary.map { [$0.rawValue] } ?? []) : exp.feltWords
        if !feltWords.isEmpty {
            lines.append("| Felt words | \(feltWords.joined(separator: ", ")) |")
        }
        lines.append("")

        let supplements = exp.supplements.sorted { $0.effectiveTime < $1.effectiveTime }
        if !supplements.isEmpty {
            lines.append("## Supplements")
            for s in supplements {
                let when = (s.takenAt ?? s.scheduledFor).map { BotanicFormat.clock($0) } ?? "scheduled"
                var row = "- **\(s.name)**"
                if let how = s.howTaking { row += " — \(how)" }
                row += " (\(when))"
                lines.append(row)
                if let intention = s.intention { lines.append("  - _Intention: \(intention)_") }
            }
            lines.append("")
        }

        let timelineLines = timeline(for: exp)
        if !timelineLines.isEmpty {
            lines.append("## Timeline")
            lines.append(contentsOf: timelineLines)
            lines.append("")
        }

        if let note = exp.noteToFuture, !note.isEmpty {
            lines.append("## Note to future me")
            lines.append("> \(note)")
            lines.append("")
        }

        lines.append("---")
        lines.append("_Exported from Botanic — a private journal. Stored on device. Not medical advice._")
        return lines.joined(separator: "\n")
    }

    /// Chronological check-ins and notes, interleaved by time. Check-ins render their three slider
    /// words (via `CheckInWordEngine`, the same mapping the live check-in sheet uses) plus any
    /// selected chip words and note; freeform journal entries render as plain timestamped lines.
    private static func timeline(for exp: Experience) -> [String] {
        enum Moment {
            case checkIn(CheckIn)
            case journal(JournalEntry)

            var date: Date {
                switch self {
                case .checkIn(let c): return c.createdAt
                case .journal(let j): return j.createdAt
                }
            }
        }

        let moments = (exp.checkIns.map(Moment.checkIn) + exp.journalEntries.map(Moment.journal))
            .sorted { $0.date < $1.date }

        return moments.map { moment in
            switch moment {
            case .checkIn(let c):
                let valenceWord = CheckInWordEngine.valenceWord(c.valence)
                let intensityWord = CheckInWordEngine.intensityWord(c.intensity)
                let bodyLoadWord = CheckInWordEngine.bodyLoadWord(c.bodyLoad)
                var row = "- \(BotanicFormat.clock(c.createdAt)) — **Check-in**"
                if let feeling = c.feeling { row += " · \(feeling.rawValue)" }
                row += " (\(valenceWord) · \(intensityWord) · \(bodyLoadWord))"
                if !c.tags.isEmpty { row += " — \(c.tags.joined(separator: ", "))" }
                if let note = c.note, !note.isEmpty { row += "\n  - _\(note)_" }
                return row
            case .journal(let j):
                return "- \(BotanicFormat.clock(j.createdAt)) — \(j.text)"
            }
        }
    }
}
