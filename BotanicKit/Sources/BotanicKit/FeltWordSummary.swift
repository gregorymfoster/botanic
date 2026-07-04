import Foundation

/// Summarizes the chip words a user reached for across an experience's check-ins into a short,
/// representative list for the end-of-experience recap.
public enum FeltWordSummary {
    /// The top `limit` words across `checkInWords` (one array of chips per check-in, chronological),
    /// ordered by frequency descending. Ties are broken by recency — a word seen in a later check-in
    /// ranks above one last seen earlier. Matching is case-insensitive and deduplicated, but the
    /// first-seen casing of each word is preserved in the output.
    public static func top(from checkInWords: [[String]], limit: Int = 3) -> [String] {
        var displayCasing: [String: String] = [:]
        var counts: [String: Int] = [:]
        var lastSeenIndex: [String: Int] = [:]

        for (index, chips) in checkInWords.enumerated() {
            for word in chips {
                let key = word.lowercased()
                guard !key.isEmpty else { continue }
                if displayCasing[key] == nil { displayCasing[key] = word }
                counts[key, default: 0] += 1
                lastSeenIndex[key] = index
            }
        }

        let ranked = counts.keys.sorted { lhs, rhs in
            let lc = counts[lhs] ?? 0
            let rc = counts[rhs] ?? 0
            if lc != rc { return lc > rc }
            let lLast = lastSeenIndex[lhs] ?? -1
            let rLast = lastSeenIndex[rhs] ?? -1
            if lLast != rLast { return lLast > rLast }
            return lhs < rhs
        }

        return ranked.prefix(limit).map { displayCasing[$0] ?? $0 }
    }
}
