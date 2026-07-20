import ActivityKit
import AppIntents
import BotanicKit
import SwiftUI
import WidgetKit

/// The Botanic Live Activity: a calm presence on the lock screen and Dynamic Island for the life of
/// an experience. Elapsed time self-renders via `Text(timerInterval:)`, so the app only pushes
/// updates when supplement / check-in counts change. Quick actions are LiveActivityIntent buttons,
/// which execute in the app process and write through the app-owned store.
struct BotanicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BotanicActivityAttributes.self) { context in
            LockScreenLiveView(state: context.state, experienceID: context.attributes.experienceID)
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
                    HStack(spacing: 8) {
                        CheckInButton(experienceID: context.attributes.experienceID)
                        EndButton(experienceID: context.attributes.experienceID)
                    }
                }
            } compactLeading: {
                Image(systemName: "leaf.fill").foregroundStyle(DuskWidget.peach)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                Image(systemName: "leaf.fill").foregroundStyle(DuskWidget.peach)
            }
            .keylineTint(DuskWidget.peach)
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
    let experienceID: UUID

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
                HStack(spacing: 6) {
                    CheckInButton(experienceID: experienceID)
                    EndButton(experienceID: experienceID)
                }
            }
        }
        .background {
            if #available(iOS 27.0, *) {
                StandByBackground()
            }
        }
    }
}

private struct CheckInButton: View {
    let experienceID: UUID

    var body: some View {
        Button(intent: CheckInLiveActivityIntent(experienceID: experienceID)) {
            Label("Check in", systemImage: "circle.dashed.inset.filled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DuskWidget.text)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Capsule().fill(DuskWidget.peach.opacity(0.24)))
        }
        .buttonStyle(.plain)
    }
}

private struct EndButton: View {
    let experienceID: UUID

    var body: some View {
        Button(intent: EndLiveActivityIntent(experienceID: experienceID)) {
            Label("End", systemImage: "stop.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DuskWidget.text)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Capsule().fill(DuskWidget.lavender.opacity(0.22)))
        }
        .buttonStyle(.plain)
    }
}

private struct CompactTrailingView: View {
    let state: BotanicActivityAttributes.ContentState

    var body: some View {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            LimitedWidthCompactTrailingView(state: state)
        } else {
            elapsed
        }
#else
        elapsed
#endif
    }

    private var elapsed: some View {
        Text(timerInterval: state.startedAt...(state.endedAt ?? .distantFuture), countsDown: false)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(DuskWidget.peach)
            .frame(maxWidth: 68, alignment: .trailing)
    }
}

/// Landscape Dynamic Island compact presentations have a fixed narrow width in iOS 27. Keep the
/// timer in the expanded presentation and use an unambiguous glyph here instead of truncating it.
#if compiler(>=6.4)
@available(iOS 27.0, *)
private struct LimitedWidthCompactTrailingView: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth
    let state: BotanicActivityAttributes.ContentState

    var body: some View {
        if isLimitedInWidth {
            Image(systemName: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DuskWidget.peach)
                .accessibilityLabel("Experience timer")
        } else {
            Text(timerInterval: state.startedAt...(state.endedAt ?? .distantFuture), countsDown: false)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DuskWidget.peach)
                .frame(maxWidth: 68, alignment: .trailing)
        }
    }
}
#endif

/// StandBy scales the lock-screen presentation up in landscape. On iOS 27, the container
/// background environment lets the activity extend its dusk surface edge-to-edge in that mode.
@available(iOS 27.0, *)
private struct StandByBackground: View {
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    var body: some View {
        if showsWidgetContainerBackground {
            LinearGradient(
                colors: [DuskWidget.surface, DuskWidget.surface.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
