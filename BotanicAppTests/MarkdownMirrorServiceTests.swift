import BotanicKit
import Foundation
import SwiftData
import Testing
@testable import Botanic

@MainActor
private func makeContext() -> ModelContext {
    let schema = Schema([Experience.self, SupplementEntry.self, CheckIn.self, JournalEntry.self, SupplementLibraryItem.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

private let mirrorFolder = URL(fileURLWithPath: "/fake/MirrorFolder")
private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14

/// Builds a `MarkdownMirrorService` wired to a fresh `FakeFileSystem`/`UserDefaults` suite, with a
/// folder resolver that hands back `mirrorFolder` directly (bookmark resolution itself is
/// device-only and isn't under test here). A non-nil bookmark is pre-seeded so `isConfigured` is
/// true, matching a real "folder already chosen" state.
@MainActor
private func makeService(fakeFS: FakeFileSystem, defaults: UserDefaults) -> MarkdownMirrorService {
    defaults.set(true, forKey: MarkdownMirrorService.mirrorEnabledKey)
    defaults.set(Data([0x01]), forKey: MarkdownMirrorService.mirrorBookmarkKey)
    return MarkdownMirrorService(
        defaults: defaults,
        fileSystem: fakeFS,
        folderResolver: { _ in (mirrorFolder, nil) }
    )
}

@Suite("MarkdownMirrorService")
struct MarkdownMirrorServiceTests {
    @MainActor
    @Test func syncWritesExpectedFilename() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        let context = makeContext()

        let experience = Experience(title: "Evening Walk", startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(3600))
        context.insert(experience)

        service.sync(experience, in: context)

        let expectedName = MarkdownFileNaming.filename(date: fixedDate, title: "Evening Walk", pattern: .dateTitle)
        let expectedURL = mirrorFolder.appendingPathComponent(expectedName)

        #expect(experience.markdownFilename == expectedName)
        #expect(fakeFS.writtenFiles[expectedURL] != nil)
    }

    @MainActor
    @Test func syncIsNoOpWhenExperienceStillLive() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        let context = makeContext()

        let experience = Experience(title: "Still Going", startedAt: fixedDate, endedAt: nil)
        context.insert(experience)

        service.sync(experience, in: context)

        #expect(experience.markdownFilename == nil)
        #expect(fakeFS.writtenFiles.isEmpty)
    }

    @MainActor
    @Test func syncIsNoOpWhenMirroringDisabled() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        defaults.set(false, forKey: MarkdownMirrorService.mirrorEnabledKey)
        let context = makeContext()

        let experience = Experience(title: "Disabled", startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(60))
        context.insert(experience)

        service.sync(experience, in: context)

        #expect(experience.markdownFilename == nil)
        #expect(fakeFS.writtenFiles.isEmpty)
    }

    @MainActor
    @Test func syncResolvesFilenameCollisionWithSuffix() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        let context = makeContext()

        let desiredName = MarkdownFileNaming.filename(date: fixedDate, title: "Duplicate", pattern: .dateTitle)
        // Pre-seed the folder with a file of the name a fresh sync would want to use.
        fakeFS.directoryContents[mirrorFolder.path] = [desiredName]

        let experience = Experience(title: "Duplicate", startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(60))
        context.insert(experience)

        service.sync(experience, in: context)

        let expectedCollisionName = MarkdownFileNaming.resolveCollision(desiredName, existing: [desiredName])
        #expect(experience.markdownFilename == expectedCollisionName)
        #expect(expectedCollisionName != desiredName)
    }

    @MainActor
    @Test func renamingTitleRemovesOldFileAndWritesNewOne() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        let context = makeContext()

        let experience = Experience(title: "Original Title", startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(60))
        context.insert(experience)

        service.sync(experience, in: context)
        let originalName = experience.markdownFilename
        #expect(originalName != nil)
        let originalURL = mirrorFolder.appendingPathComponent(originalName!)
        #expect(fakeFS.writtenFiles[originalURL] != nil)

        experience.title = "Renamed Title"
        service.sync(experience, in: context)

        let newName = experience.markdownFilename
        #expect(newName != originalName)
        #expect(fakeFS.removedURLs.contains(originalURL))
        #expect(fakeFS.writtenFiles[originalURL] == nil)

        let newURL = mirrorFolder.appendingPathComponent(newName!)
        #expect(fakeFS.writtenFiles[newURL] != nil)
    }

    @MainActor
    @Test func syncAllOnlyMirrorsFinishedExperiences() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = makeService(fakeFS: fakeFS, defaults: defaults)
        let context = makeContext()

        let finished = Experience(title: "Finished", startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(60))
        let live = Experience(title: "Still Live", startedAt: fixedDate, endedAt: nil)
        context.insert(finished)
        context.insert(live)

        service.syncAll(experiences: [finished, live], in: context)

        #expect(finished.markdownFilename != nil)
        #expect(live.markdownFilename == nil)
    }

    @MainActor
    @Test func resolveFolderReturnsNilAndClearsBookmarkWhenResolutionFails() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(Data([0x01]), forKey: MarkdownMirrorService.mirrorBookmarkKey)

        let service = MarkdownMirrorService(defaults: defaults, fileSystem: fakeFS, folderResolver: { _ in nil })

        #expect(service.resolveFolder() == nil)
        #expect(defaults.data(forKey: MarkdownMirrorService.mirrorBookmarkKey) == nil)
    }

    @MainActor
    @Test func resolveFolderPersistsRefreshedBookmarkWhenStale() {
        let fakeFS = FakeFileSystem()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(Data([0x01]), forKey: MarkdownMirrorService.mirrorBookmarkKey)
        let refreshedData = Data([0x02])

        let service = MarkdownMirrorService(
            defaults: defaults,
            fileSystem: fakeFS,
            folderResolver: { _ in (mirrorFolder, refreshedData) }
        )

        #expect(service.resolveFolder() == mirrorFolder)
        #expect(defaults.data(forKey: MarkdownMirrorService.mirrorBookmarkKey) == refreshedData)
    }
}
