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
enum MarkdownMirrorService {
    /// `@AppStorage` keys — keep in sync with `SettingsView`.
    static let mirrorEnabledKey = "mirrorEnabled"
    static let mirrorBookmarkKey = "mirrorFolderBookmark"
    static let fileNamingPatternKey = "markdownFilePattern"

    private static let logger = Logger(subsystem: "com.botanic.app", category: "MarkdownMirror")

    /// Mirroring defaults **on** — it only actually writes once a folder has been chosen
    /// (`isConfigured`), so the default reflects the design's "on" toggle without requiring setup.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: mirrorEnabledKey) as? Bool ?? true
    }

    static var isConfigured: Bool {
        UserDefaults.standard.data(forKey: mirrorBookmarkKey) != nil
    }

    static var pattern: MarkdownFilePattern {
        let stored = UserDefaults.standard.string(forKey: fileNamingPatternKey)
        return stored.flatMap(MarkdownFilePattern.init(rawValue:)) ?? .dateTitle
    }

    // MARK: - Folder selection

    /// Persists a security-scoped bookmark for a folder picked via `.fileImporter`/document picker.
    /// iOS bookmarks (unlike macOS) are created without `.withSecurityScope` — that option is
    /// macOS-only and throws on iOS.
    static func setFolder(_ url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData(options: [])
        UserDefaults.standard.set(bookmark, forKey: mirrorBookmarkKey)
    }

    /// Resolves the stored bookmark back to a URL. Re-saves the bookmark if the system flags it as
    /// stale but is still able to resolve it; drops the bookmark entirely if resolution fails.
    static func resolveFolder() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: mirrorBookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale, let refreshed = try? url.bookmarkData(options: []) {
                UserDefaults.standard.set(refreshed, forKey: mirrorBookmarkKey)
            }
            return url
        } catch {
            logger.error("Failed to resolve mirror folder bookmark: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: mirrorBookmarkKey)
            return nil
        }
    }

    // MARK: - Sync

    /// Mirrors a single finished experience to the configured folder: writes (or rewrites) its
    /// Markdown file, renaming/removing the previous file if the title changed. No-op unless mirroring
    /// is enabled, a folder is configured, and the experience has ended. Never throws — failures are
    /// logged and left for the next sync attempt.
    static func sync(_ experience: Experience, in context: ModelContext) {
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
            logger.error("Failed to save markdownFilename after mirror sync: \(error.localizedDescription)")
        }
    }

    /// Re-mirrors every finished experience — used after the folder changes or mirroring is toggled
    /// back on, so previously-unmirrored (or differently-located) experiences catch up.
    static func syncAll(experiences: [Experience], in context: ModelContext) {
        for experience in experiences where experience.endedAt != nil {
            sync(experience, in: context)
        }
    }

    // MARK: - Sharing

    /// A temporary, non-security-scoped copy of an experience's markdown suitable for `ShareLink`.
    /// Sharing the mirrored file directly would require holding security-scoped access open for the
    /// life of the share sheet, so instead we regenerate the markdown fresh into the temp directory.
    static func temporaryShareURL(for experience: Experience) -> URL? {
        let name = experience.markdownFilename
            ?? MarkdownFileNaming.filename(date: experience.startedAt, title: experience.title, pattern: pattern)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let markdown = MarkdownExport.experience(experience.markdownExportInput())
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("Failed to write temporary share file: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Zip export

    /// Writes every finished experience's markdown into a fresh temp folder, then asks
    /// `NSFileCoordinator` to zip it (`.forUploading` hands back a zipped temporary URL for directory
    /// reads — the documented, dependency-free way to zip on iOS), and copies that zip to a stable
    /// path so the caller can hand it to a share sheet.
    static func exportZipURL(experiences: [Experience]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folderURL = tempDir.appendingPathComponent("Botanic Journal")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let finished = experiences.filter { $0.endedAt != nil }
        for experience in finished {
            let name = experience.markdownFilename
                ?? MarkdownFileNaming.filename(date: experience.startedAt, title: experience.title, pattern: pattern)
            let fileURL = folderURL.appendingPathComponent(name)
            let markdown = MarkdownExport.experience(experience.markdownExportInput())
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
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

        let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent("Botanic Journal.zip")
        if FileManager.default.fileExists(atPath: stableURL.path) {
            try FileManager.default.removeItem(at: stableURL)
        }
        try FileManager.default.copyItem(at: zippedURL, to: stableURL)
        return stableURL
    }

    // MARK: - Helpers

    /// Lists the base filenames already present in `folder`, excluding `excluded` (the experience's
    /// own current file, so re-syncing the same experience doesn't treat its own file as a collision).
    private static func folderContents(_ folder: URL, excluding excluded: String?) -> Set<String> {
        var names: Set<String> = []
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: folder, options: [], error: &coordinatorError) { readURL in
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: readURL.path)) ?? []
            names = Set(contents)
        }
        if let coordinatorError {
            logger.error("Failed to list mirror folder contents: \(coordinatorError.localizedDescription)")
        }
        if let excluded { names.remove(excluded) }
        return names
    }

    /// Writes `text` to `destination` atomically via `NSFileCoordinator`, so a concurrent iCloud sync
    /// of the same folder doesn't race the write. Returns whether the write succeeded.
    @discardableResult
    private static func writeCoordinated(_ text: String, to destination: URL) -> Bool {
        var coordinatorError: NSError?
        var succeeded = false
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: destination, options: [.forReplacing], error: &coordinatorError) { writeURL in
            do {
                try text.write(to: writeURL, atomically: true, encoding: .utf8)
                succeeded = true
            } catch {
                logger.error("Failed to write mirror file: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("File coordinator error writing mirror file: \(coordinatorError.localizedDescription)")
        }
        return succeeded
    }

    private static func removeCoordinated(_ url: URL) {
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: [.forDeleting], error: &coordinatorError) { deleteURL in
            try? FileManager.default.removeItem(at: deleteURL)
        }
        if let coordinatorError {
            logger.error("File coordinator error removing stale mirror file: \(coordinatorError.localizedDescription)")
        }
    }
}
