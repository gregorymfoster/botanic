import BotanicKit
import Foundation
import OSLog
import SwiftData

extension Experience {
    /// Bridges this SwiftData model into the framework-free input `MarkdownExport` (in BotanicKit)
    /// renders from — the kit can't see `@Model` types, so this is the one place that maps them.
    func markdownExportInput(asOf now: Date = Date()) -> MarkdownExportInput {
        MarkdownExportInput(
            title: title,
            subtitle: subtitle,
            startedAt: startedAt,
            duration: duration(asOf: now),
            feltWords: feltWords,
            feltSummary: feltSummary,
            supplements: supplements.map { s in
                MarkdownExportInput.Supplement(
                    name: s.name,
                    howTaking: s.howTaking,
                    intention: s.intention,
                    // `MarkdownExport` shows "scheduled" when this is nil; pass the same
                    // taken-or-scheduled fallback the original inline builder used.
                    takenAt: s.takenAt ?? s.scheduledFor,
                    effectiveTime: s.effectiveTime
                )
            },
            checkIns: checkIns.map { c in
                MarkdownExportInput.CheckIn(
                    createdAt: c.createdAt,
                    valence: c.valence,
                    intensity: c.intensity,
                    bodyLoad: c.bodyLoad,
                    feeling: c.feeling,
                    tags: c.tags,
                    note: c.note
                )
            },
            journalEntries: journalEntries.map { j in
                MarkdownExportInput.JournalEntry(createdAt: j.createdAt, text: j.text)
            },
            noteToFuture: noteToFuture
        )
    }
}

/// Mirrors finished experiences to a user-chosen folder as Markdown files, and builds the "Export
/// everything as .zip" archive. Preferences live in `UserDefaults`, matching `NotificationManager`'s
/// shape — Settings binds to the same keys via `@AppStorage`, and this enum reads them directly.
@MainActor
struct MarkdownMirrorService {
    /// `@AppStorage` keys — keep in sync with `SettingsView`.
    static let mirrorEnabledKey = "mirrorEnabled"
    static let mirrorBookmarkKey = "mirrorFolderBookmark"
    static let fileNamingPatternKey = "markdownFilePattern"

    /// The shared production instance — wired to `UserDefaults.standard`, the real filesystem, and
    /// real security-scoped bookmark resolution. Existing call sites (`MarkdownMirrorService.sync`,
    /// `.syncAll`, etc.) forward to this via the `static` funcs below, so they stay one line.
    static let live = MarkdownMirrorService()

    private static let logger = Logger(subsystem: "com.botanic.app", category: "MarkdownMirror")

    private let defaults: UserDefaults
    private let fileSystem: any FileSystem
    /// Resolves the stored bookmark to a folder URL, along with a refreshed bookmark to persist if
    /// the system flagged the original as stale. Defaults to the real security-scoped bookmark
    /// resolution (device-only); tests inject a closure that hands back a folder URL directly so the
    /// bookmark machinery itself never has to run under test.
    private let folderResolver: (Data) -> (url: URL, refreshedBookmark: Data?)?

    init(
        defaults: UserDefaults = .standard,
        fileSystem: any FileSystem = LiveFileSystem(),
        folderResolver: ((Data) -> (url: URL, refreshedBookmark: Data?)?)? = nil
    ) {
        self.defaults = defaults
        self.fileSystem = fileSystem
        self.folderResolver = folderResolver ?? Self.resolveBookmark
    }

    /// Mirroring defaults **on** — it only actually writes once a folder has been chosen
    /// (`isConfigured`), so the default reflects the design's "on" toggle without requiring setup.
    var isEnabled: Bool {
        defaults.object(forKey: Self.mirrorEnabledKey) as? Bool ?? true
    }

    var isConfigured: Bool {
        defaults.data(forKey: Self.mirrorBookmarkKey) != nil
    }

    var pattern: MarkdownFilePattern {
        let stored = defaults.string(forKey: Self.fileNamingPatternKey)
        return stored.flatMap(MarkdownFilePattern.init(rawValue:)) ?? .dateTitle
    }

    static var isEnabled: Bool { live.isEnabled }
    static var isConfigured: Bool { live.isConfigured }
    static var pattern: MarkdownFilePattern { live.pattern }

    // MARK: - Folder selection

    /// Persists a security-scoped bookmark for a folder picked via `.fileImporter`/document picker.
    /// iOS bookmarks (unlike macOS) are created without `.withSecurityScope` — that option is
    /// macOS-only and throws on iOS.
    func setFolder(_ url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData(options: [])
        defaults.set(bookmark, forKey: Self.mirrorBookmarkKey)
    }

    static func setFolder(_ url: URL) throws {
        try live.setFolder(url)
    }

    /// Resolves the stored bookmark back to a URL via `folderResolver`. Re-saves the bookmark if the
    /// system flags it as stale but is still able to resolve it; drops the bookmark entirely if
    /// resolution fails.
    func resolveFolder() -> URL? {
        guard let bookmark = defaults.data(forKey: Self.mirrorBookmarkKey) else { return nil }
        guard let resolved = folderResolver(bookmark) else {
            defaults.removeObject(forKey: Self.mirrorBookmarkKey)
            return nil
        }
        if let refreshedBookmark = resolved.refreshedBookmark {
            defaults.set(refreshedBookmark, forKey: Self.mirrorBookmarkKey)
        }
        return resolved.url
    }

    static func resolveFolder() -> URL? {
        live.resolveFolder()
    }

    /// The real (device-only) bookmark resolution: `URL(resolvingBookmarkData:)`, handing back a
    /// refreshed bookmark for the caller to persist if the system flagged the original as stale.
    private static func resolveBookmark(_ bookmark: Data) -> (url: URL, refreshedBookmark: Data?)? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let refreshed = isStale ? try? url.bookmarkData(options: []) : nil
            return (url, refreshed)
        } catch {
            logger.error("Failed to resolve mirror folder bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Sync

    /// Mirrors a single finished experience to the configured folder: writes (or rewrites) its
    /// Markdown file, renaming/removing the previous file if the title changed. No-op unless mirroring
    /// is enabled, a folder is configured, and the experience has ended. Never throws — failures are
    /// logged and left for the next sync attempt.
    func sync(_ experience: Experience, in context: ModelContext) {
        guard isEnabled, isConfigured, experience.endedAt != nil else { return }
        guard let folder = resolveFolder() else { return }

        let didAccess = folder.startAccessingSecurityScopedResource()
        defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }

        let existingNames = folderContents(folder, excluding: experience.markdownFilename)
        let desired = MarkdownFileNaming.filename(date: experience.startedAt, title: experience.title, pattern: pattern)
        let finalName = MarkdownFileNaming.resolveCollision(desired, existing: existingNames)

        let markdown = MarkdownExport.experience(experience.markdownExportInput())
        let destination = folder.appendingPathComponent(finalName)

        guard writeCoordinated(markdown, to: destination) else { return }

        if let oldName = experience.markdownFilename, oldName != finalName {
            removeCoordinated(folder.appendingPathComponent(oldName))
        }

        experience.markdownFilename = finalName
        do { try context.save() } catch {
            Self.logger.error("Failed to save markdownFilename after mirror sync: \(error.localizedDescription)")
        }
    }

    static func sync(_ experience: Experience, in context: ModelContext) {
        live.sync(experience, in: context)
    }

    /// Re-mirrors every finished experience — used after the folder changes or mirroring is toggled
    /// back on, so previously-unmirrored (or differently-located) experiences catch up.
    func syncAll(experiences: [Experience], in context: ModelContext) {
        for experience in experiences where experience.endedAt != nil {
            sync(experience, in: context)
        }
    }

    static func syncAll(experiences: [Experience], in context: ModelContext) {
        live.syncAll(experiences: experiences, in: context)
    }

    // MARK: - Sharing

    /// A temporary, non-security-scoped copy of an experience's markdown suitable for `ShareLink`.
    /// Sharing the mirrored file directly would require holding security-scoped access open for the
    /// life of the share sheet, so instead we regenerate the markdown fresh into the temp directory.
    func temporaryShareURL(for experience: Experience) -> URL? {
        let name = experience.markdownFilename
            ?? MarkdownFileNaming.filename(date: experience.startedAt, title: experience.title, pattern: pattern)
        let url = fileSystem.temporaryDirectory.appendingPathComponent(name)
        let markdown = MarkdownExport.experience(experience.markdownExportInput())
        do {
            try fileSystem.write(markdown, to: url)
            return url
        } catch {
            Self.logger.error("Failed to write temporary share file: \(error.localizedDescription)")
            return nil
        }
    }

    static func temporaryShareURL(for experience: Experience) -> URL? {
        live.temporaryShareURL(for: experience)
    }

    // MARK: - Zip export

    /// Writes every finished experience's markdown into a fresh temp folder, then asks
    /// `NSFileCoordinator` to zip it (`.forUploading` hands back a zipped temporary URL for directory
    /// reads — the documented, dependency-free way to zip on iOS), and copies that zip to a stable
    /// path so the caller can hand it to a share sheet.
    func exportZipURL(experiences: [Experience]) throws -> URL {
        let tempDir = fileSystem.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folderURL = tempDir.appendingPathComponent("Botanic Journal")
        try fileSystem.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let finished = experiences.filter { $0.endedAt != nil }
        for experience in finished {
            let name = experience.markdownFilename
                ?? MarkdownFileNaming.filename(date: experience.startedAt, title: experience.title, pattern: pattern)
            let fileURL = folderURL.appendingPathComponent(name)
            let markdown = MarkdownExport.experience(experience.markdownExportInput())
            try fileSystem.write(markdown, to: fileURL)
        }

        var coordinatorError: NSError?
        var zippedURL: URL?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: folderURL, options: [.forUploading], error: &coordinatorError) { zipped in
            zippedURL = zipped
        }

        if let coordinatorError { throw coordinatorError }
        guard let zippedURL else {
            throw NSError(domain: "MarkdownMirrorService", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive."])
        }

        let stableURL = fileSystem.temporaryDirectory.appendingPathComponent("Botanic Journal.zip")
        if fileSystem.fileExists(atPath: stableURL.path) {
            try fileSystem.removeItem(at: stableURL)
        }
        try fileSystem.copyItem(at: zippedURL, to: stableURL)
        return stableURL
    }

    static func exportZipURL(experiences: [Experience]) throws -> URL {
        try live.exportZipURL(experiences: experiences)
    }

    // MARK: - Helpers

    /// Lists the base filenames already present in `folder`, excluding `excluded` (the experience's
    /// own current file, so re-syncing the same experience doesn't treat its own file as a collision).
    private func folderContents(_ folder: URL, excluding excluded: String?) -> Set<String> {
        var names: Set<String> = []
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: folder, options: [], error: &coordinatorError) { readURL in
            let contents = (try? fileSystem.contentsOfDirectory(atPath: readURL.path)) ?? []
            names = Set(contents)
        }
        if let coordinatorError {
            Self.logger.error("Failed to list mirror folder contents: \(coordinatorError.localizedDescription)")
        }
        if let excluded { names.remove(excluded) }
        return names
    }

    /// Writes `text` to `destination` atomically via `NSFileCoordinator`, so a concurrent iCloud sync
    /// of the same folder doesn't race the write. Returns whether the write succeeded.
    @discardableResult
    private func writeCoordinated(_ text: String, to destination: URL) -> Bool {
        var coordinatorError: NSError?
        var succeeded = false
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: destination, options: [.forReplacing], error: &coordinatorError) { writeURL in
            do {
                try fileSystem.write(text, to: writeURL)
                succeeded = true
            } catch {
                Self.logger.error("Failed to write mirror file: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            Self.logger.error("File coordinator error writing mirror file: \(coordinatorError.localizedDescription)")
        }
        return succeeded
    }

    private func removeCoordinated(_ url: URL) {
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: [.forDeleting], error: &coordinatorError) { deleteURL in
            try? fileSystem.removeItem(at: deleteURL)
        }
        if let coordinatorError {
            Self.logger.error("File coordinator error removing stale mirror file: \(coordinatorError.localizedDescription)")
        }
    }
}
