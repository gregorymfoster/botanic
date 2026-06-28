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

- Botanic is a descriptive journal. Copy never advises doses, never recommends substances, and the
  Grounding screen always offers emergency services. Keep insights descriptive ("evenings with X
  tended to feel calmer"), never prescriptive.
