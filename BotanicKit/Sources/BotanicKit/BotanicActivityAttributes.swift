#if os(iOS)
import ActivityKit
import Foundation

/// The Live Activity contract, shared between the app (which starts / updates / ends the activity)
/// and the BotanicWidgets extension (which renders it). Framework-free of SwiftData — the app maps
/// its `Experience` into plain values here, mirroring the `ExperienceSnapshot` / `TimelineEntry`
/// bridges so the package never references SwiftData.
///
/// Guarded by `#if os(iOS)` so the package still builds for macOS (`swift test`) — ActivityKit's
/// module imports on macOS but `ActivityAttributes` is marked unavailable there.
public struct BotanicActivityAttributes: ActivityAttributes {
    /// The live, per-update fields. Elapsed time is derived on the widget from `startedAt` via
    /// `Text(timerInterval:)`, so the app never has to push timer ticks.
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        /// Set when the experience closes — freezes the widget's elapsed clock at this instant.
        /// `nil` while live (the timer counts up open-endedly).
        public var endedAt: Date?
        public var title: String
        public var supplementCount: Int
        public var checkInCount: Int
        /// The most recently taken supplement's name, for the compact labels (optional).
        public var latestSupplement: String?

        public init(
            startedAt: Date,
            endedAt: Date? = nil,
            title: String,
            supplementCount: Int,
            checkInCount: Int,
            latestSupplement: String? = nil
        ) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.title = title
            self.supplementCount = supplementCount
            self.checkInCount = checkInCount
            self.latestSupplement = latestSupplement
        }
    }

    /// Fixed for the activity's life. Ties a running activity back to its `Experience` on relaunch.
    public var experienceID: UUID

    public init(experienceID: UUID) {
        self.experienceID = experienceID
    }
}
#endif
