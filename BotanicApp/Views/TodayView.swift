import BotanicKit
import SwiftUI

struct TodayView: View {
    var live: Experience?
    var onAdd: () -> Void
    var onCheckIn: () -> Void
    var onNote: () -> Void
    var onGround: () -> Void
    var onSupport: () -> Void
    var onEnd: () -> Void

    var body: some View {
        Group {
            if let live {
                LiveExperienceView(experience: live, onAdd: onAdd, onCheckIn: onCheckIn,
                                   onNote: onNote, onGround: onGround, onSupport: onSupport, onEnd: onEnd)
            } else {
                IdleTodayView(onAdd: onAdd)
            }
        }
    }
}

// MARK: - Idle

private struct IdleTodayView: View {
    var onAdd: () -> Void

    private var dayPart: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Date().formatted(.dateTime.weekday(.wide))
        let part = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<22: "evening"
        default: "night"
        }
        return "\(weekday) \(part)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: dayPart, color: Dusk.pinkSoft)
            Text("Begin an\nexperience")
                .font(Dusk.serif(32, .medium))
                .foregroundStyle(Dusk.text)
                .padding(.top, 8)

            Spacer(minLength: 0)

            VStack(spacing: 18) {
                BloomOrb()
                Text("Nothing logged yet. Add your first\nsupplement whenever you're ready.")
                    .font(Dusk.serifItalic(16))
                    .foregroundStyle(Dusk.muted(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            Button(action: onAdd) {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                    Text("Add supplement")
                }
            }
            .buttonStyle(DuskPrimaryButton())
            .accessibilityHint("Starts a new experience")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Live

private struct LiveExperienceView: View {
    var experience: Experience
    var onAdd: () -> Void
    var onCheckIn: () -> Void
    var onNote: () -> Void
    var onGround: () -> Void
    var onSupport: () -> Void
    var onEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    heroCard
                    supplementsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .padding(.bottom, 12)
            }

            actionsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .padding(.top, 8)
    }

    private var header: some View {
        HStack {
            LivePill()
            Spacer()
            Button(action: onEnd) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill").font(.system(size: 11))
                    Text("End experience").font(Dusk.sans(12, .semibold))
                }
                .foregroundStyle(Dusk.pinkSoft)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .glassCard(fill: 0.07, stroke: Dusk.glassStrokeStrong, cornerRadius: 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(title: experience.title, color: Dusk.pinkSoft)
                    Text(subtitle)
                        .font(Dusk.sans(12))
                        .foregroundStyle(Dusk.muted(0.5))
                }
                Spacer()
                Text(experience.duration(asOf: context.date).botanicDuration)
                    .font(Dusk.serif(34, .light))
                    .foregroundStyle(Dusk.text)
            }
            .padding(16)
            .warmGlassCard()
        }
    }

    private var subtitle: String {
        let logged = experience.loggedSupplements.count
        let scheduled = experience.scheduledSupplements.count
        var parts = ["since \(BotanicFormat.clock(experience.startedAt))", "\(logged) logged"]
        if scheduled > 0 { parts.append("\(scheduled) scheduled") }
        return parts.joined(separator: " · ")
    }

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Supplements", color: Dusk.muted(0.42))
                .padding(.top, 2)

            ForEach(experience.loggedSupplements) { entry in
                SupplementRow(entry: entry)
            }
            ForEach(experience.scheduledSupplements) { entry in
                ScheduledSupplementRow(entry: entry)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                    Text("Add supplement").font(Dusk.sans(13.5, .semibold))
                }
                .foregroundStyle(Dusk.muted(0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .glassCard(fill: 0.04, cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 9) {
            actionButton("Check in", "clock", hint: "Log how right now feels", action: onCheckIn)
            actionButton("Note", "text.alignleft", hint: "Open the journal timeline", action: onNote)
            actionButton("Ground", "leaf", hint: "Breathing and grounding steps", action: onGround)
            actionButton("Support", "phone", hint: "Reach your support person", action: onSupport)
        }
    }

    private func actionButton(_ title: String, _ icon: String, hint: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .regular))
                Text(title).font(Dusk.sans(11, .semibold))
            }
            .foregroundStyle(Dusk.text)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .glassCard(fill: 0.07, stroke: Dusk.glassStrokeStrong, cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}

// MARK: - Supplement rows

struct SupplementRow: View {
    var entry: SupplementEntry

    var body: some View {
        HStack(spacing: 13) {
            SupplementSwatch(colorIndex: entry.colorIndex)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(Dusk.sans(15, .semibold))
                    .foregroundStyle(Dusk.text)
                if let how = entry.howTaking {
                    Text(how)
                        .font(Dusk.sans(12))
                        .foregroundStyle(Dusk.muted(0.5))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let taken = entry.takenAt {
                Text(BotanicFormat.clock(taken))
                    .font(Dusk.serif(13.5))
                    .foregroundStyle(Dusk.muted(0.6))
            }
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .glassCard(fill: 0.055, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = [entry.name]
        if let how = entry.howTaking { parts.append(how) }
        if let taken = entry.takenAt { parts.append("taken at \(BotanicFormat.clock(taken))") }
        return parts.joined(separator: ", ")
    }
}

struct ScheduledSupplementRow: View {
    var entry: SupplementEntry

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Dusk.lavender.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "clock")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Dusk.lavender)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(Dusk.sans(15, .semibold))
                    .foregroundStyle(Dusk.text)
                Text("scheduled\(entry.howTaking.map { " · \($0)" } ?? "")")
                    .font(Dusk.sans(12))
                    .foregroundStyle(Dusk.muted(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let when = entry.scheduledFor {
                Text(BotanicFormat.relativeToNow(when))
                    .font(Dusk.serif(13.5))
                    .foregroundStyle(Dusk.lavender)
            }
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Dusk.lavender.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = [entry.name, "scheduled"]
        if let how = entry.howTaking { parts.append(how) }
        if let when = entry.scheduledFor { parts.append(BotanicFormat.relativeToNow(when)) }
        return parts.joined(separator: ", ")
    }
}
