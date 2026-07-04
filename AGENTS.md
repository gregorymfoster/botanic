# Agent Guide

## Repo Map

- `BotanicKit`: shared Swift package — `DuskPalette`, `FeelingWord`, `JournalPrompt`,
  `InsightsEngine`, `Formatting`, and package tests. Framework-free and deterministic.
- `BotanicApp`: iPhone SwiftUI app — SwiftData models, `Dusk` design system, screens, components.
- `project.yml`: XcodeGen source of truth for `Botanic.xcodeproj`.

## Safe Commands

```sh
xcodegen generate
swift test --package-path BotanicKit
xcodebuild -project Botanic.xcodeproj -scheme Botanic -destination 'generic/platform=iOS Simulator' build
```

## Local Verify Gate

There is no cloud CI — `scripts/check.sh` is the canonical "is it safe to commit/release?" gate.

```sh
scripts/check.sh            # full: package tests → xcodegen → simulator build (+ swiftlint if configured)
scripts/check.sh --fast     # package tests only — the inner dev loop
scripts/check.sh --release  # full gate plus a clean build, before tagging a release
```

Run the full gate before committing and the `--release` gate before releasing. To enforce it
automatically, `scripts/install-hooks.sh` wires `pre-commit → check.sh --fast` and
`pre-push → check.sh` (opt-in, per contributor; bypass once with `git commit/push --no-verify`).

> Screenshot note: capturing `NavigationStack`-backed tabs (History, Settings, and pushed Insights/
> Detail) via `simctl io screenshot` currently renders blank on the Xcode 26 simulator; sheet-based
> screens (Add, Journal, etc.) capture fine. Verify those tabs by manual navigation.

## Change Notes

- Prefer adding computation (insights, formatting, vocab) to `BotanicKit` with package tests first;
  keep persistence and UI state in `BotanicApp`.
- `InsightsEngine` works over framework-free `ExperienceSnapshot` value types. The app maps SwiftData
  models → snapshots, then calls the engine — never reference SwiftData inside the package.
- If new Swift files are added to the app target, update `project.yml` and run `xcodegen generate`.
- `Botanic.xcodeproj` is gitignored — it's regenerated, never hand-edited.

## iOS Practices

- **Deployment target is iOS 17.** Use modern APIs freely; do not add `if #available` guards.
- **Concurrency:** UI and view-model state types are `@MainActor`. Prefer `async`/`await` and
  `Task {}` over `DispatchQueue`.
- **No force-unwraps in app code.** Avoid `!`, `try!`, `as!`; handle the `nil`/throwing path.
- **Accessibility is a quality bar.** VoiceOver labels on controls and the orbs, Dynamic Type
  support, and nothing critical conveyed by color or motion alone (respect Reduce Motion).

## Product Guardrails

- Botanic is a descriptive journal, not a source of medical advice. Copy never advises doses, never
  recommends substances, and stays descriptive rather than prescriptive. Keep insights descriptive
  ("evenings with X tended to feel calmer"), never prescriptive.
