# Botanic

A private supplement & experience journal for iPhone. Native SwiftUI, on-device, user-authored —
**not** dosing advice or medical guidance.

Two actions drive the app: **add a supplement** (which starts a live *experience* if none is
running) and **end the experience**. Within a live experience you log more supplements, check-ins,
notes, and freeform journal entries; ending writes it to history and opens a short reflection.
History surfaces past experiences, a supplements view, and computed **Insights**.

## Structure

- `BotanicKit`: shared Swift package for the Dusk palette, feeling vocabulary, journal prompts,
  pure insight math (`InsightsEngine`), and formatting — with unit tests.
- `BotanicApp`: the iPhone SwiftUI app — SwiftData persistence, the design system (`Dusk`), screens,
  and components.
- `project.yml`: XcodeGen source of truth for `Botanic.xcodeproj` (gitignored, regenerated).

## Commands

```sh
xcodegen generate
swift test --package-path BotanicKit
xcodebuild -project Botanic.xcodeproj -scheme Botanic -destination 'generic/platform=iOS Simulator' build
```

## Notes

- Minimum target is iOS 17. Modern APIs only (SwiftData `@Model`/`@Query`, Observation,
  `async`/`await`) — no `if #available` fallbacks.
- Typography is Spectral (serif display) + Hanken Grotesk (sans body), registered at launch.
- **Scoped out of v1** (called out so it isn't mistaken for done): no HealthKit / heart-rate capture
  — the design's "avg bpm" tile is omitted until present; storage is plain on-device SwiftData, so
  privacy copy reads "Stored on device" rather than claiming end-to-end encryption.
