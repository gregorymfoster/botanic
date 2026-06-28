import BotanicKit
import Foundation

/// Renders an experience to a portable, user-readable Markdown document — the "export as Markdown"
/// affordance. Private and user-authored: it's the user's own notes, nothing more.
enum MarkdownExport {
    static func experience(_ exp: Experience) -> String {
        var lines: [String] = []
        lines.append("# \(exp.title)")
        lines.append("")

        var meta = [BotanicFormat.shortDate(exp.startedAt, includeYear: true),
                    exp.duration().botanicDuration]
        if let felt = exp.feltSummary { meta.append("felt \(felt.rawValue.lowercased())") }
        if let location = exp.locationContext { meta.append(location) }
        lines.append("_\(meta.joined(separator: " · "))_")
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

        let checkIns = exp.checkIns.sorted { $0.createdAt < $1.createdAt }
        if !checkIns.isEmpty {
            lines.append("## Check-ins")
            for c in checkIns {
                let feeling = c.feeling?.rawValue ?? "—"
                var row = "- \(BotanicFormat.clock(c.createdAt)) — **\(feeling)**"
                if !c.tags.isEmpty { row += " (\(c.tags.joined(separator: ", ")))" }
                lines.append(row)
            }
            lines.append("")
        }

        let journal = exp.journalEntries.sorted { $0.createdAt < $1.createdAt }
        if !journal.isEmpty {
            lines.append("## Journal")
            for j in journal {
                lines.append("- \(BotanicFormat.clock(j.createdAt)) — \(j.text)")
            }
            lines.append("")
        }

        if let note = exp.noteToFuture {
            lines.append("## Note to future me")
            lines.append("> \(note)")
            lines.append("")
        }

        lines.append("---")
        lines.append("_Exported from Botanic — a private journal. Stored on device. Not medical advice._")
        return lines.joined(separator: "\n")
    }
}
