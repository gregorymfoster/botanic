import BotanicKit
import SwiftData
import SwiftUI

struct TodayView: View {
    var live: Experience?
    var onAdd: () -> Void
    /// Fired by the "Again tonight?" quick-add cards with a draft prefilled from a library item —
    /// distinct from `onAdd` (the blank-sheet entry point) so RootView can seed `addPrefill` first.
    var onQuickAdd: (SupplementDraft) -> Void
    var onCheckIn: () -> Void
    var onNote: () -> Void
    var onEnd: () -> Void

    var body: some View {
        Group {
            if let live {
                LiveExperienceView(experience: live, onAdd: onAdd, onCheckIn: onCheckIn,
                                   onNote: onNote, onEnd: onEnd)
            } else {
                IdleTodayView(onAdd: onAdd, onQuickAdd: onQuickAdd)
            }
        }
    }
}

// MARK: - Idle

private struct IdleTodayView: View {
    var onAdd: () -> Void
    var onQuickAdd: (SupplementDraft) -> Void

    @Query(sort: \SupplementLibraryItem.lastUsedAt, order: .reverse) private var libraryItems: [SupplementLibraryItem]

    private var recentItems: [SupplementLibraryItem] { Array(libraryItems.prefix(2)) }

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

            if !recentItems.isEmpty {
                againTonightSection
                    .padding(.bottom, 16)
            }

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

    private var againTonightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Again tonight?", color: Dusk.pinkSoft)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                ForEach(recentItems) { item in
                    QuickAddCard(item: item) {
                        onQuickAdd(SupplementDraft(prefillingFrom: item))
                    }
                }
            }
        }
    }
}

/// One "Again tonight?" quick-add card: a stable color dot derived from the supplement's name, its
/// name, and the last amount used. Tapping seeds the Add sheet from this library entry.
private struct QuickAddCard: View {
    var item: SupplementLibraryItem
    var action: () -> Void

    /// A stable index into the shared supplement swatch palette. `String.hashValue` is randomly
    /// seeded per launch, so a scalar sum keeps the same supplement on the same color across runs.
    private var colorIndex: Int {
        item.name.lowercased().unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SupplementSwatch(colorIndex: colorIndex, size: 26, checked: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(Dusk.sans(13, .semibold))
                        .foregroundStyle(Dusk.text)
                        .lineLimit(1)
                    if let amount = item.lastAmount, !amount.isEmpty {
                        Text(amount)
                            .font(Dusk.sans(10.5))
                            .foregroundStyle(Dusk.muted(0.55))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .glassCard(fill: 0.055, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Prefills the Add supplement sheet from your last log")
    }

    private var accessibilityLabel: String {
        var parts = [item.name]
        if let amount = item.lastAmount, !amount.isEmpty { parts.append(amount) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Live

private struct LiveExperienceView: View {
    var experience: Experience
    var onAdd: () -> Void
    var onCheckIn: () -> Void
    var onNote: () -> Void
    var onEnd: () -> Void

    @State private var showingTimeline = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // One scroll view holding the session — hero, supplements, and the last check-in snippet
            // — so the content passes *under* the Liquid Glass tab bar. The two primary live actions
            // (Check in / Note) live in a docked capsule below, pinned above the tab bar instead of
            // scrolling with the content.
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    heroCard
                    supplementsSection
                    lastCheckInSnippet
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)
                // Extra bottom padding so the last row clears the docked action capsule instead of
                // sitting behind it.
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                dockedActionCapsule
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showingTimeline) {
            timelineSheet
        }
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

    /// A compact preview of the most recent check-in — its elapsed stamp, feeling word, chip words,
    /// and note if present. Tapping opens the full timeline as a sheet. Shows nothing when the
    /// experience has no check-ins yet (the docked capsule invites the first one).
    @ViewBuilder private var lastCheckInSnippet: some View {
        if let lastCheckIn = experience.checkIns.max(by: { $0.createdAt < $1.createdAt }) {
            Button {
                showingTimeline = true
            } label: {
                HStack(alignment: .top, spacing: 13) {
                    VStack(spacing: 6) {
                        Text(elapsedStamp(for: lastCheckIn.createdAt))
                            .font(Dusk.sans(11, .bold))
                            .foregroundStyle(Dusk.peach)
                        Rectangle()
                            .fill(LinearGradient(colors: [Dusk.peach.opacity(0.4), .clear],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 1.5)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: 34)
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("LAST CHECK-IN\(lastCheckIn.feeling.map { " · \($0.rawValue.uppercased())" } ?? "")")
                            .font(Dusk.sans(10, .bold)).tracking(1.4)
                            .foregroundStyle(Dusk.pinkSoft)
                        if !lastCheckIn.tags.isEmpty {
                            Text(lastCheckIn.tags.joined(separator: " · "))
                                .font(Dusk.serifItalic(15.5))
                                .foregroundStyle(Dusk.text)
                        }
                        if let note = lastCheckIn.note, !note.isEmpty {
                            Text("\u{201C}\(note)\u{201D}")
                                .font(Dusk.serifItalic(14))
                                .foregroundStyle(Dusk.muted(0.72))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Dusk.muted(0.35))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmGlassCard()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lastCheckInAccessibilityLabel(for: lastCheckIn))
            .accessibilityHint("Opens the full timeline")
        }
    }

    private func elapsedStamp(for date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(experience.startedAt)))
        return String(format: "%d:%02d", total / 3600, (total % 3600) / 60)
    }

    private func lastCheckInAccessibilityLabel(for checkIn: CheckIn) -> String {
        var parts = ["Last check-in"]
        if let feeling = checkIn.feeling { parts.append(feeling.rawValue) }
        if !checkIn.tags.isEmpty { parts.append(checkIn.tags.joined(separator: ", ")) }
        if let note = checkIn.note, !note.isEmpty { parts.append("note: \(note)") }
        return parts.joined(separator: ", ")
    }

    /// The docked glass capsule holding the two primary live actions, pinned above the tab bar via
    /// `.safeAreaInset`. Grounding/support actions are intentionally not on this screen (v2 change).
    private var dockedActionCapsule: some View {
        HStack(spacing: 8) {
            Button(action: onCheckIn) {
                HStack(spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 15, weight: .semibold))
                    Text("Check in").font(Dusk.sans(15, .bold))
                }
                .foregroundStyle(Dusk.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(Dusk.accentGradient))
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
            .accessibilityLabel("Check in")
            .accessibilityHint("Log how right now feels")

            Button(action: onNote) {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft").font(.system(size: 14, weight: .semibold))
                    Text("Note").font(Dusk.sans(15, .semibold))
                }
                .foregroundStyle(Dusk.text)
                .frame(width: 96)
                .frame(height: 46)
                .background(Capsule().fill(.white.opacity(0.09)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Note")
            .accessibilityHint("Write a freeform note")
        }
        .padding(6)
        .frame(height: 62)
        .glassCard(fill: 0.09, stroke: Dusk.glassStrokeStrong, cornerRadius: 31)
    }

    private var timelineSheet: some View {
        let entries = ExperienceStore.timelineEntries(for: experience)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        TimelineRow(entry: entry, isLast: index == entries.count - 1)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(DuskBackground(live: true).ignoresSafeArea())
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingTimeline = false }
                        .font(Dusk.sans(14, .semibold))
                        .tint(Dusk.pinkSoft)
                }
            }
        }
        .presentationBackground(.clear)
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
