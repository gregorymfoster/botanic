import Foundation

/// Narrow seam over the `FileManager`/string-write calls that `BackupManager` and
/// `MarkdownMirrorService` actually make, so both can be exercised in unit tests with an in-memory
/// fake instead of touching the real disk. `NSFileCoordinator` itself stays real (coordinating a
/// fake location is meaningless) — this seam covers only the read/write/remove work the coordinator
/// hands a URL to.
protocol FileSystem {
    /// Mirrors `FileManager.url(for:in:appropriateFor:create:)`.
    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor: URL?, create: Bool) throws -> URL

    /// Mirrors `FileManager.contentsOfDirectory(atPath:)`.
    func contentsOfDirectory(atPath path: String) throws -> [String]

    /// Mirrors `FileManager.createDirectory(at:withIntermediateDirectories:)`.
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws

    /// Mirrors `FileManager.fileExists(atPath:)`.
    func fileExists(atPath path: String) -> Bool

    /// Mirrors `FileManager.removeItem(at:)`.
    func removeItem(at url: URL) throws

    /// Mirrors `FileManager.copyItem(at:to:)`.
    func copyItem(at srcURL: URL, to dstURL: URL) throws

    /// Mirrors `String.write(to:atomically:encoding:)`.
    func write(_ text: String, to url: URL) throws

    /// Mirrors `FileManager.temporaryDirectory`.
    var temporaryDirectory: URL { get }

    /// Sets `URLResourceValues.isExcludedFromBackup` on `url` — used by `BackupManager` to flip
    /// iCloud/iTunes backup exclusion on the SwiftData store files.
    func setExcludedFromBackup(_ excluded: Bool, at url: URL) throws
}

/// Production `FileSystem` — thin wrapper over `FileManager.default` (and `String.write` /
/// `URLResourceValues` for the two calls that aren't `FileManager` methods).
struct LiveFileSystem: FileSystem {
    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor: URL?, create: Bool) throws -> URL {
        try FileManager.default.url(for: directory, in: domain, appropriateFor: appropriateFor, create: create)
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }

    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try FileManager.default.copyItem(at: srcURL, to: dstURL)
    }

    func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func setExcludedFromBackup(_ excluded: Bool, at url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try mutableURL.setResourceValues(values)
    }
}
