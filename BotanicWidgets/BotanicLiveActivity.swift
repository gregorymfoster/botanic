import ActivityKit
import BotanicKit
import SwiftUI
import WidgetKit

/// The Botanic Live Activity: a calm presence on the lock screen and Dynamic Island for the life of
/// an experience. Elapsed time self-renders via `Text(timerInterval:)`, so the app only pushes
/// updates when supplement / check-in counts change. The "Check in" affordance deep-links into the
/// app's check-in sheet (`botanic://checkin`) — logging needs the app's slider UI.
struct BotanicLiveActivity: Widget {
    private static let checkInURL = URL(string: "botanic://checkin")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BotanicActivityAttributes.self) { context in
            LockScreenLiveView(state: context.state, checkInURL: Self.checkInURL)
                .padding(16)
                .activityBackgroundTint(DuskWidget.surface.opacity(0.92))
                .activitySystemActionForegroundColor(DuskWidget.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.supplementCount)", systemImage: "leaf.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DuskWidget.peach)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsed(from: context.state.startedAt, to: context.state.endedAt)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(DuskWidget.peach)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .foregroundStyle(DuskWidget.text)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: Self.checkInURL) {
                        Label("Check in", systemImage: "circle.dashed.inset.filled")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DuskWidget.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(DuskWidget.peach.opacity(0.22))
                            )
                    }
                }
            } compactLeading: {
                Image(systemName: "leaf.fill").foregroundStyle(DuskWidget.peach)
            } compactTrailing: {
                elapsed(from: context.state.startedAt, to: context.state.endedAt)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DuskWidget.peach)
                    .frame(maxWidth: 68, alignment: .trailing)
            } minimal: {
                Image(systemName: "leaf.fill").foregroundStyle(DuskWidget.peach)
            }
            .keylineTint(DuskWidget.peach)
            .widgetURL(Self.checkInURL)
        }
    }

    /// A counting-up elapsed clock the OS redraws on its own. Once `end` is set the interval closes,
    /// freezing the timer at the experience's final duration so an ended activity stops ticking.
    private func elapsed(from start: Date, to end: Date?) -> some View {
        Text(timerInterval: start...(end ?? .distantFuture), countsDown: false)
    }
}

/// The lock-screen / banner presentation.
private struct LockScreenLiveView: View {
    let state: BotanicActivityAttributes.ContentState
    let checkInURL: URL

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle().fill(DuskWidget.peach).frame(width: 7, height: 7)
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(DuskWidget.text)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Label("\(state.supplementCount)", systemImage: "leaf.fill")
                        .foregroundStyle(DuskWidget.pinkSoft)
                    Label("\(state.checkInCount)", systemImage: "circle.dashed")
                        .foregroundStyle(DuskWidget.lavender)
                }
                .font(.caption.weight(.medium))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(timerInterval: state.startedAt...(state.endedAt ?? .distantFuture), countsDown: false)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(DuskWidget.peach)
                    .frame(maxWidth: 90, alignment: .trailing)
                Link(destination: checkInURL) {
                    Text("Check in")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DuskWidget.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DuskWidget.peach.opacity(0.24)))
                }
            }
        }
    }
}
