import Foundation
import OSLog

/// Controls whether the SwiftData store is included in the user's iCloud/iTunes device backup.
/// Defaults **on** (standard app-data backup, restorable on a new phone); Settings can turn it off
/// for people who prefer only the Markdown mirror as their backup. Applies by flipping
/// `URLResourceValues.isExcludedFromBackup` on the default SwiftData store files.
@MainActor
enum BackupManager {
    static let icloudBackupEnabledKey = "icloudBackupEnabled"

    private static let logger = Logger(subsystem: "com.botanic.app", category: "BackupManager")

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: icloudBackupEnabledKey) as? Bool ?? true
    }

    /// Re-applies the current `isEnabled` preference to the on-disk store files. Call once at launch
    /// and again whenever the Settings toggle changes.
    static func apply() {
        let excluded = !isEnabled
        for url in storeFileURLs() {
            var mutableURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = excluded
            do {
                try mutableURL.setResourceValues(values)
            } catch {
                logger.error("Failed to set isExcludedFromBackup on \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// The SwiftData default store and its `-shm`/`-wal` siblings in Application Support, if present.
    private static func storeFileURLs() -> [URL] {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return [] }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: appSupport.path)) ?? []
        return contents
            .filter { $0.hasPrefix("default.store") }
            .map { appSupport.appendingPathComponent($0) }
    }
}
