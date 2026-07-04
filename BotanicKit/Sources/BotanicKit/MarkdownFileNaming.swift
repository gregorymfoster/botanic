import Foundation

/// The filename patterns available when exporting an experience to Markdown.
public enum MarkdownFilePattern: String, CaseIterable, Sendable {
    case dateTitle
    case titleOnly
    case dateOnly

    /// A sample filename illustrating this pattern, for display in settings.
    public var example: String {
        switch self {
        case .dateTitle: return "2026-07-04 Title.md"
        case .titleOnly: return "Title.md"
        case .dateOnly: return "2026-07-04.md"
        }
    }
}

/// Builds sanitized, deterministic Markdown filenames for exported experiences.
public enum MarkdownFileNaming {
    private static let forbiddenCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
    private static let maxTitleLength = 80

    /// Builds a filename for `date`/`title` under the given `pattern`. The title is sanitized:
    /// forbidden filesystem characters and control characters are stripped, runs of whitespace are
    /// collapsed to a single space, the result is trimmed, and truncated to ~80 characters. A title
    /// that sanitizes to empty falls back to "Untitled". The date component uses a fixed
    /// `en_US_POSIX` locale and formats as `yyyy-MM-dd`, so output is stable across the user's locale
    /// and calendar settings.
    public static func filename(
        date: Date,
        title: String,
        pattern: MarkdownFilePattern = .dateTitle,
        calendar: Calendar = .current
    ) -> String {
        let datePart = formattedDate(date, calendar: calendar)
        switch pattern {
        case .dateOnly:
            return "\(datePart).md"
        case .titleOnly:
            return "\(sanitize(title)).md"
        case .dateTitle:
            return "\(datePart) \(sanitize(title)).md"
        }
    }

    /// Appends " (2)", " (3)", … before the ".md" extension until `candidate` is not present in
    /// `existing`. Returns `candidate` unchanged if it's already unique.
    public static func resolveCollision(_ candidate: String, existing: Set<String>) -> String {
        guard existing.contains(candidate) else { return candidate }

        let base: String
        let ext: String
        if let dotRange = candidate.range(of: ".md", options: [.backwards, .caseInsensitive]),
           dotRange.upperBound == candidate.endIndex {
            base = String(candidate[candidate.startIndex..<dotRange.lowerBound])
            ext = String(candidate[dotRange])
        } else {
            base = candidate
            ext = ""
        }

        var suffix = 2
        while true {
            let attempt = "\(base) (\(suffix))\(ext)"
            if !existing.contains(attempt) { return attempt }
            suffix += 1
        }
    }

    // MARK: - Helpers

    private static func formattedDate(_ date: Date, calendar: Calendar) -> String {
        var formatCalendar = calendar
        formatCalendar.locale = Locale(identifier: "en_US_POSIX")
        let f = DateFormatter()
        f.calendar = formatCalendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func sanitize(_ title: String) -> String {
        let stripped = title.unicodeScalars
            .filter { !forbiddenCharacters.contains($0) && !CharacterSet.controlCharacters.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }

        let collapsed = stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled" }

        if trimmed.count > maxTitleLength {
            return String(trimmed.prefix(maxTitleLength))
        }
        return trimmed
    }
}
