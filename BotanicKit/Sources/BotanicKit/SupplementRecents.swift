import Foundation

/// A framework-free snapshot of one supplement's usage history, mapped from the app's SwiftData
/// library so recency/search logic stays pure and testable.
public struct SupplementLibrarySnapshot: Equatable, Sendable {
    public let name: String
    public let lastAmount: String?
    public let lastIntention: String?
    public let useCount: Int
    public let lastUsedAt: Date

    public init(
        name: String,
        lastAmount: String?,
        lastIntention: String?,
        useCount: Int,
        lastUsedAt: Date
    ) {
        self.name = name
        self.lastAmount = lastAmount
        self.lastIntention = lastIntention
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}

/// Orders and filters the supplement library for the check-in "recents" picker.
public enum SupplementRecents {
    /// Most-recently-used first. When `query` is non-empty, keeps only items whose name matches
    /// case-insensitively — either a prefix match on any whitespace-separated word of the name, or a
    /// substring match anywhere in the name. Ties in recency keep their original relative order
    /// (a stable sort). An optional `limit` caps the result count.
    public static func recents(
        _ items: [SupplementLibrarySnapshot],
        matching query: String = "",
        limit: Int? = nil
    ) -> [SupplementLibrarySnapshot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered: [SupplementLibrarySnapshot]
        if trimmed.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { item in
                let name = item.name.lowercased()
                if name.contains(trimmed) { return true }
                return name
                    .split(whereSeparator: { $0.isWhitespace })
                    .contains { $0.hasPrefix(trimmed) }
            }
        }

        let sorted = filtered.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.lastUsedAt != rhs.element.lastUsedAt {
                    return lhs.element.lastUsedAt > rhs.element.lastUsedAt
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }
}
