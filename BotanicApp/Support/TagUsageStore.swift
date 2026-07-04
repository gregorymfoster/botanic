import Foundation

/// Persists per-tag usage counts so frequently used tags/words can be surfaced first — backs the
/// check-in "words you use often float to the front" ordering used by
/// `CheckInWordEngine.orderedTags` (BotanicKit/Sources/BotanicKit/CheckInWordEngine.swift).
enum TagUsageStore {
    private static let key = "tagUsageCounts"

    static func counts() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return decoded
    }

    static func increment(_ tags: [String]) {
        guard !tags.isEmpty else { return }
        var current = counts()
        for tag in tags { current[tag, default: 0] += 1 }
        guard let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
