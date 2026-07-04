import Foundation
import Testing
@testable import Botanic

/// In-memory `FileSystem` fake: tracks directory listings and which URLs have been marked excluded
/// from backup, without touching the real disk.
final class FakeFileSystem: FileSystem, @unchecked Sendable {
    var directoryContents: [String: [String]] = [:]
    var writtenFiles: [URL: String] = [:]
    var removedURLs: [URL] = []
    var copiedItems: [(from: URL, to: URL)] = []
    var excludedFromBackup: [URL: Bool] = [:]
    var applicationSupportURL = URL(fileURLWithPath: "/fake/ApplicationSupport")
    var temporaryDirectoryURL = URL(fileURLWithPath: "/fake/tmp")
    var shouldFailCreateDirectory = false

    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor: URL?, create: Bool) throws -> URL {
        applicationSupportURL
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        directoryContents[path] ?? []
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        if shouldFailCreateDirectory {
            throw NSError(domain: "FakeFileSystem", code: 1)
        }
        directoryContents[url.path] = directoryContents[url.path] ?? []
    }

    func fileExists(atPath path: String) -> Bool {
        writtenFiles.keys.contains { $0.path == path }
    }

    func removeItem(at url: URL) throws {
        removedURLs.append(url)
        writtenFiles.removeValue(forKey: url)
        let parent = url.deletingLastPathComponent().path
        directoryContents[parent]?.removeAll { $0 == url.lastPathComponent }
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copiedItems.append((srcURL, dstURL))
        writtenFiles[dstURL] = writtenFiles[srcURL] ?? ""
    }

    func write(_ text: String, to url: URL) throws {
        writtenFiles[url] = text
        let parent = url.deletingLastPathComponent().path
        var contents = directoryContents[parent] ?? []
        if !contents.contains(url.lastPathComponent) {
            contents.append(url.lastPathComponent)
        }
        directoryContents[parent] = contents
    }

    var temporaryDirectory: URL { temporaryDirectoryURL }

    func setExcludedFromBackup(_ excluded: Bool, at url: URL) throws {
        excludedFromBackup[url] = excluded
    }
}

@Suite("BackupManager")
struct BackupManagerTests {
    @MainActor
    @Test func applyExcludesStoreFilesWhenBackupDisabled() {
        let fakeFS = FakeFileSystem()
        fakeFS.directoryContents[fakeFS.applicationSupportURL.path] = [
            "default.store", "default.store-shm", "default.store-wal", "unrelated.txt",
        ]
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: BackupManager.icloudBackupEnabledKey)

        let manager = BackupManager(defaults: defaults, fileSystem: fakeFS)
        #expect(manager.isEnabled == false)

        manager.apply()

        let storeURL = fakeFS.applicationSupportURL.appendingPathComponent("default.store")
        let shmURL = fakeFS.applicationSupportURL.appendingPathComponent("default.store-shm")
        let walURL = fakeFS.applicationSupportURL.appendingPathComponent("default.store-wal")
        let unrelatedURL = fakeFS.applicationSupportURL.appendingPathComponent("unrelated.txt")

        #expect(fakeFS.excludedFromBackup[storeURL] == true)
        #expect(fakeFS.excludedFromBackup[shmURL] == true)
        #expect(fakeFS.excludedFromBackup[walURL] == true)
        #expect(fakeFS.excludedFromBackup[unrelatedURL] == nil)
    }

    @MainActor
    @Test func applyIncludesStoreFilesWhenBackupEnabled() {
        let fakeFS = FakeFileSystem()
        fakeFS.directoryContents[fakeFS.applicationSupportURL.path] = ["default.store"]
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: BackupManager.icloudBackupEnabledKey)

        let manager = BackupManager(defaults: defaults, fileSystem: fakeFS)
        manager.apply()

        let storeURL = fakeFS.applicationSupportURL.appendingPathComponent("default.store")
        #expect(fakeFS.excludedFromBackup[storeURL] == false)
    }

    @MainActor
    @Test func isEnabledDefaultsToTrueWhenUnset() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = BackupManager(defaults: defaults, fileSystem: FakeFileSystem())
        #expect(manager.isEnabled == true)
    }

    @MainActor
    @Test func togglingSettingFlipsExclusionOnReapply() {
        let fakeFS = FakeFileSystem()
        fakeFS.directoryContents[fakeFS.applicationSupportURL.path] = ["default.store"]
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: BackupManager.icloudBackupEnabledKey)

        let manager = BackupManager(defaults: defaults, fileSystem: fakeFS)
        let storeURL = fakeFS.applicationSupportURL.appendingPathComponent("default.store")

        manager.apply()
        #expect(fakeFS.excludedFromBackup[storeURL] == false)

        defaults.set(false, forKey: BackupManager.icloudBackupEnabledKey)
        manager.apply()
        #expect(fakeFS.excludedFromBackup[storeURL] == true)
    }
}
