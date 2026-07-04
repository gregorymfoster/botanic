import Foundation
import OSLog

/// Controls whether the SwiftData store is included in the user's iCloud/iTunes device backup.
/// Defaults **on** (standard app-data backup, restorable on a new phone); Settings can turn it off
/// for people who prefer only the Markdown mirror as their backup. Applies by flipping
/// `URLResourceValues.isExcludedFromBackup` on the default SwiftData store files.
@MainActor
struct BackupManager {
    static let icloudBackupEnabledKey = "icloudBackupEnabled"

    /// The shared production instance — wired to `UserDefaults.standard` and the real filesystem.
    /// `BackupManager.apply()` forwards to this so the `BotanicApp.init` call site stays one line.
    static let live = BackupManager()

    private static let logger = Logger(subsystem: "com.botanic.app", category: "BackupManager")

    private let defaults: UserDefaults
    private let fileSystem: any FileSystem

    init(defaults: UserDefaults = .standard, fileSystem: any FileSystem = LiveFileSystem()) {
        self.defaults = defaults
        self.fileSystem = fileSystem
    }

    var isEnabled: Bool {
        defaults.object(forKey: Self.icloudBackupEnabledKey) as? Bool ?? true
    }

    /// Convenience static entry point so callers that only need the production instance's current
    /// preference (e.g. `@AppStorage`-adjacent reads) don't have to thread `.live` through.
    static var isEnabled: Bool {
        live.isEnabled
    }

    /// Re-applies the current `isEnabled` preference to the on-disk store files. Call once at launch
    /// and again whenever the Settings toggle changes.
    static func apply() {
        live.apply()
    }

    /// Instance form of `apply()` — re-applies the current `isEnabled` preference to the on-disk
    /// store files.
    func apply() {
        let excluded = !isEnabled
        for url in storeFileURLs() {
            do {
                try fileSystem.setExcludedFromBackup(excluded, at: url)
            } catch {
                Self.logger.error("Failed to set isExcludedFromBackup on \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// The SwiftData default store and its `-shm`/`-wal` siblings in Application Support, if present.
    private func storeFileURLs() -> [URL] {
        guard let appSupport = try? fileSystem.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return [] }

        let contents = (try? fileSystem.contentsOfDirectory(atPath: appSupport.path)) ?? []
        return contents
            .filter { $0.hasPrefix("default.store") }
            .map { appSupport.appendingPathComponent($0) }
    }
}
