import Foundation

/// Persists per-tag usage counts so frequently used tags/words can be surfaced first — backs the
/// check-in "words you use often float to the front" ordering used by
/// `CheckInWordEngine.orderedTags` (BotanicKit/Sources/BotanicKit/CheckInWordEngine.swift).
struct TagUsageStore {
    private static let key = "tagUsageCounts"

    /// The shared production instance — wired to `UserDefaults.standard`. Existing call sites
    /// (`TagUsageStore.counts()`, `.increment(_:)`) forward to this via the `static` funcs below.
    static let live = TagUsageStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func counts() -> [String: Int] {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return decoded
    }

    func increment(_ tags: [String]) {
        guard !tags.isEmpty else { return }
        var current = counts()
        for tag in tags { current[tag, default: 0] += 1 }
        guard let data = try? JSONEncoder().encode(current) else { return }
        defaults.set(data, forKey: Self.key)
    }

    static func counts() -> [String: Int] {
        live.counts()
    }

    static func increment(_ tags: [String]) {
        live.increment(tags)
    }
}
