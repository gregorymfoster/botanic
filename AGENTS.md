# Agent Guide

## Repo Map

- `BotanicKit`: shared Swift package — `DuskPalette`, `FeelingWord`/`PresenceGroup`,
  `JournalPrompt`, `InsightsEngine`, `Formatting`, `CheckInWordEngine`, `SupplementRecents`,
  `MarkdownFileNaming`, `ExperienceSummaryGenerator` (deterministic fallback), `FeltWordSummary`,
  and package tests. Framework-free and deterministic; platform floor stays iOS 17.
- `BotanicApp`: iPhone SwiftUI app — SwiftData models, `Dusk` design system, screens, components,
  and services (`MarkdownMirrorService`, `BackupManager`, `NotificationManager`,
  `FoundationModelsSummarizer`).
- `project.yml`: XcodeGen source of truth for `Botanic.xcodeproj`.

## Safe Commands

```sh
xcodegen generate
swift test --package-path BotanicKit
xcodebuild -project Botanic.xcodeproj -scheme Botanic -destination 'generic/platform=iOS Simulator' build
xcodebuild test -project Botanic.xcodeproj -scheme Botanic -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Tests

- **BotanicKit tests** (`BotanicKit/Tests/BotanicKitTests`, run as target `BotanicKitTests`): framework-free
  package tests. Fastest path: `swift test --package-path BotanicKit`.
- **BotanicAppTests** (`BotanicAppTests/`): app-hosted unit test bundle (`@testable import Botanic`),
  wired as a hosted test target (`TEST_HOST`/`BUNDLE_LOADER` pointed at the `Botanic.app` binary) so it
  can exercise SwiftData models, stores, and other app-target code that can't move into BotanicKit.
  Covers `ExperienceStore` lifecycle rules, `NotificationManager`, `BackupManager`,
  `MarkdownMirrorService`, and `TagUsageStore` via injected fakes (in-memory SwiftData, fake
  `FileSystem`, suite-scoped `UserDefaults`). Add coverage here for store/service logic that lives
  in the app target; put pure logic in BotanicKit instead.
- **`Botanic` scheme's test action** runs both `BotanicKitTests` and `BotanicAppTests` with
  `gatherCoverageData: true`. Invoke directly with:
  ```sh
  xcodebuild test -project Botanic.xcodeproj -scheme Botanic -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
  ```

## Local Verify Gate

`scripts/check.sh` is the canonical "is it safe to commit/release?" gate, run locally.

```sh
scripts/check.sh            # full: package tests → xcodegen → simulator build+test (BotanicKitTests + BotanicAppTests) (+ swiftlint if configured)
scripts/check.sh --fast     # package tests only — the inner dev loop
scripts/check.sh --release  # full gate, with a clean build+test, before tagging a release
```

`check.sh`'s full and `--release` modes now run `xcodebuild test` (not just `build`) against the
`Botanic` scheme, so both the `BotanicKitTests` and `BotanicAppTests` bundles execute on every full
gate run, piped through `xcbeautify` when it's installed. `--fast` still only runs the BotanicKit
package tests, for a quick inner loop.

Run the full gate before committing and the `--release` gate before releasing. To enforce it
automatically, `scripts/install-hooks.sh` wires `pre-commit → check.sh --fast` and
`pre-push → check.sh` (opt-in, per contributor; bypass once with `git commit/push --no-verify`).

## Cloud CI

`.github/workflows/ci.yml` runs on GitHub Actions on every push to `main` and every pull request,
mirroring `scripts/check.sh`'s two tiers as separate jobs on `macos-26` runners (Xcode 26 selected
via `Xcode_26*.app`):

- **`kit-tests`**: `swift test --package-path BotanicKit` — fails fast before the slower app tier runs.
- **`app-tests`** (needs `kit-tests`): installs `xcodegen`, runs `xcodegen generate`, creates a
  deterministic iOS Simulator with `xcrun simctl create` (newest available iOS runtime + an iPhone
  device type, since hosted runners don't reliably have a device named "iPhone 17 Pro Max"), then runs
  `xcodebuild test -project Botanic.xcodeproj -scheme Botanic -destination 'platform=iOS
  Simulator,id=<created-udid>' -enableCodeCoverage YES`, piped through `xcbeautify` when present. The
  build log and `.xcresult` are used for a coverage summary and uploaded as an artifact on failure.
  `CODE_SIGNING_ALLOWED=NO` is set since simulator destinations don't need signing.

**This workflow is unverified** — it has been validated for YAML syntax (`actionlint`, which passes
cleanly including its embedded shellcheck) and its `simctl`/`xcresulttool` logic was smoke-tested
locally, but no run has actually executed on a GitHub-hosted runner yet. Treat the first push/PR run
as the real test; fix forward if the runner image or Xcode path assumptions don't hold.

> Screenshot note: capturing `NavigationStack`-backed tabs (History, Settings, and pushed Insights/
> Detail) via `simctl io screenshot` currently renders blank on the Xcode 26 simulator; sheet-based
> screens (Add, Journal, etc.) capture fine. Verify those tabs by manual navigation.

## Deterministic Launch Args

For agent-driven screenshots and manual verification, the app supports launch arguments that seed
data and jump straight to a known state:

- `-seedSampleData` (`BotanicApp/Support/SampleData.swift`): seeds a body of finished experiences
  plus one live experience, but only if there are no existing experiences.
- `-seedSampleHistory` (`BotanicApp/Support/SampleData.swift`): seeds only finished experiences, so
  Today stays idle. Also only applies when there are no existing experiences.
- `-initialTab <today|history|settings|insights>` (`BotanicApp/Views/RootView.swift`): selects the
  starting tab. `insights` selects History and then opens the Insights push after a short delay.
- `-openSheet <add|checkin|journal|note|end>` (`BotanicApp/Views/RootView.swift`): opens the named
  sheet shortly after launch (`journal` and `note` both open the note sheet).
- `-openDetail` (`BotanicApp/Views/RootView.swift`): selects History and pushes the most recently
  finished experience's detail view.

These are read from `ProcessInfo.processInfo.arguments` and are only meant for screenshots/manual
QA — they're not a general-purpose testing seam (see `BotanicAppTests` for that).

## Change Notes

- Prefer adding computation (insights, formatting, vocab) to `BotanicKit` with package tests first;
  keep persistence and UI state in `BotanicApp`.
- `InsightsEngine` works over framework-free `ExperienceSnapshot` value types. The app maps SwiftData
  models → snapshots, then calls the engine — never reference SwiftData inside the package.
- If new Swift files are added to the app target, update `project.yml` and run `xcodegen generate`.
- `Botanic.xcodeproj` is gitignored — it's regenerated, never hand-edited.
- On-device AI lives **only in the app target**: `FoundationModelsSummarizer` wraps Apple's
  FoundationModels behind BotanicKit's `ExperienceSummarizing` protocol and always falls back to
  `DeterministicExperienceSummarizer`. Never import FoundationModels inside `BotanicKit`.

## iOS Practices

- **Deployment target is iOS 26 for the app target** (FoundationModels); `BotanicKit` stays at
  iOS 17. Use modern APIs freely in the app; do not add `if #available` guards below iOS 26.
- **Concurrency:** UI and view-model state types are `@MainActor`. Prefer `async`/`await` and
  `Task {}` over `DispatchQueue`.
- **No force-unwraps in app code.** Avoid `!`, `try!`, `as!`; handle the `nil`/throwing path.
- **Accessibility is a quality bar.** VoiceOver labels on controls and the orbs, Dynamic Type
  support, and nothing critical conveyed by color or motion alone (respect Reduce Motion).
- **Automation identifiers are centralized.** Every interactive element carries an
  `.accessibilityIdentifier` from the `AccessibilityID` namespace
  (`BotanicApp/Support/AccessibilityID.swift`), grouped by screen. UI tests and agent tooling must
  target these identifiers, never user-visible copy. Add a constant there when adding a control.
- **Testability conventions** (seams, injection pattern, anti-goals) are documented in
  `docs/testability.md`.

## Sentry (crash/error reporting)

- The Sentry Cocoa SDK (`Sentry` package, `sentry-cocoa`) is a dependency of the `Botanic` app
  target only — not `BotanicWidgets`, not `BotanicKit`.
- `SentrySDK.start` is called at the top of `BotanicApp.init()` (`BotanicApp/BotanicApp.swift`),
  before the app's other setup calls. The DSN is inlined in code (Sentry DSNs are not secret — they
  only allow submitting events to the project, not reading data).
- `options.environment` is `"debug"` in Debug builds and `"production"` in Release builds.
  `options.tracesSampleRate` is `0.2`.
- **dSYM upload**: after archiving for release, upload debug symbols so stack traces symbolicate:
  ```sh
  SENTRY_AUTH_TOKEN=<token> scripts/upload-dsyms.sh [path/to/App.xcarchive]
  ```
  Defaults to the newest `*.xcarchive` under `build/` if no path is given. Requires `sentry-cli`
  (`brew install getsentry/tools/sentry-cli`) and a `SENTRY_AUTH_TOKEN` with permission to upload to
  the `gregorymfoster`/`botanic` Sentry project.

## Untested / Unverifiable Surfaces

- **`BotanicWidgets`** (the WidgetKit extension and Live Activity): no test target. WidgetKit
  timelines and Live Activities are difficult to unit test and are currently only verified by manual
  device/simulator inspection.
- **ActivityKit and UserNotifications glue** (Live Activity start/update/end, local notification
  scheduling in `NotificationManager`): these wrap device-only system frameworks and aren't
  exercised by `BotanicAppTests` or `BotanicKitTests`. Verify by hand on a real device/simulator run.

## Product Guardrails

- Botanic is a descriptive journal, not a source of medical advice. Copy never advises doses, never
  recommends substances, and stays descriptive rather than prescriptive. Keep insights descriptive
  ("evenings with X tended to feel calmer"), never prescriptive.
