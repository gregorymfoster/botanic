# Botanic testability plan

Status of the testability pass run on 2026-07-04, and the standing principles for keeping the
project testable and agent-verifiable. Companion to the practical commands in `AGENTS.md`.

## Why: where bugs clustered

Git history showed fix commits concentrating in `BotanicApp/Models/ExperienceStore.swift`
(10 changes), `SettingsView`, `RootView`, and `TodayView` — all in the app target, which had zero
automated tests. BotanicKit's pure logic was already well covered; every gap was code that had
not (yet) moved into the kit or sat behind an untestable boundary.

## Done (this pass)

- **Phase 0 — zero-refactor wins**
  - `BotanicAppTests` unit-test target (hosted by the app) + an explicit `Botanic` scheme whose
    test action runs both `BotanicKitTests` and `BotanicAppTests`.
  - `scripts/check.sh` full/`--release` modes run `xcodebuild test` (not build-only);
    `--fast` stays kit-tests-only.
  - `MarkdownExport` moved into BotanicKit behind the framework-free `MarkdownExportInput`
    bridge, with tests.
  - The triplicated hour→day-part logic unified in `TimeOfDay` (BotanicKit), preserving each
    call site's exact historic strings (including the intentional hour-21 disagreement).
  - `ExperienceStore.save` logs + reports to Sentry instead of silently swallowing errors.
  - AGENTS.md documents the deterministic launch args, real test invocations, and untested
    surfaces.
- **Phase 1 — ExperienceStore seams**
  - `ExperienceStore` is an injectable struct (`ExperienceStore.live` in production) with three
    narrow protocols: `LiveActivityUpdating`, `NotificationScheduling`, `MarkdownMirroring`
    (see `ExperienceStoreDependencies.swift`). Lifecycle rules covered by
    `BotanicAppTests/ExperienceStoreTests.swift` with recording mocks and in-memory SwiftData.
- **Phase 2 — remaining seams** (this pass, second round)
  - Pure notification decisions extracted to BotanicKit (`NotificationPolicy`); UN framework
    glue stays thin. `UserDefaults` and a narrow `FileSystem` protocol injected into
    `NotificationManager`, `BackupManager`, `MarkdownMirrorService`, `TagUsageStore`.
- **Phase 3 — CI**: `.github/workflows/ci.yml` runs the same two tiers as `scripts/check.sh`.
- **Phase 4 — agent DevX**: accessibility identifiers centralized in `AccessibilityID`
  (never match user-visible copy); deterministic launch args documented in AGENTS.md.

## Standing principles

- **Pure core, thin shell**: business logic lives in BotanicKit, tested on the host via
  `swift test` in seconds. When an app-target type grows pure logic, hoist it.
- **Constructor injection, no DI framework**: dependencies are init parameters with production
  defaults (`init(x: X = LiveX())` / resolved-in-body for MainActor defaults); the shared
  production instance is `Type.live`. Never `UserDefaults.standard` / `FileManager.default` /
  `.shared` inline in a method body of an injectable type.
- **Device-only boundaries stay mocked forever**: ActivityKit, UserNotifications, security-scoped
  bookmarks, on-device FoundationModels. Test the decision, mock the boundary; real behavior is a
  manual/device verification surface.
- **Swift Testing for new tests**; existing XCTest in BotanicKit migrates opportunistically, never
  as a project.
- **SwiftData in tests**: `ModelConfiguration(isStoredInMemoryOnly: true)`, fresh container per
  test.
- **The gate must tell the truth**: `scripts/check.sh` and CI run the same tests; docs and
  scripts reference simulators/schemes that actually exist (currently iPhone 17 Pro Max — the
  16 Pro Max simulator only exists on iOS 18.3, below the app's iOS 26 floor).

## Anti-goals

- No coverage-percentage chasing — chase the bug clusters.
- No snapshot tests (iOS 26 Liquid Glass renders transparent in snapshots) and no ViewInspector.
- No tests of framework glue itself (AVAudioEngine-style graphs, UN center calls, ActivityKit) —
  extract the pure sub-logic instead.
- No DI library; plain protocols + initializer injection only.
