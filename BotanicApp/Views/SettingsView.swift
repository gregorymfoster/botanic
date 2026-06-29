import BotanicKit
import SwiftUI

struct SettingsView: View {
    var experiences: [Experience]
    @AppStorage("supportPersonName") private var supportName = ""
    @AppStorage("supportPersonNumber") private var supportNumber = ""
    @AppStorage(NotificationManager.enabledKey) private var remindersEnabled = true
    @AppStorage(NotificationManager.intervalKey) private var reminderIntervalMinutes = 90

    private static let intervalOptions = [60, 90, 120]

    private var finished: [Experience] {
        experiences.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    private var hasLiveExperience: Bool {
        experiences.contains { $0.endedAt == nil }
    }

    /// Bridges the 60/90/120-minute preference to the `SegmentedToggle`'s 0-based index.
    private var intervalIndex: Binding<Int> {
        Binding(
            get: { Self.intervalOptions.firstIndex(of: reminderIntervalMinutes) ?? 1 },
            set: { reminderIntervalMinutes = Self.intervalOptions[$0] }
        )
    }

    /// Shown once the user starts filling in support details but the number can't be dialed — explains
    /// why the Grounding Call button stays hidden.
    private var showsNumberHint: Bool {
        (!supportName.isEmpty || !supportNumber.isEmpty) && !PhoneDialer.canDial(supportNumber)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                supportCard
                remindersCard
                privacyCard
                exportAllCard
                aboutCard
            }
            .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUPPORT PERSON")
                .font(Dusk.sans(10.5, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            Text("Shown on the Grounding screen for one-tap reach-out.")
                .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5))
            TextField("", text: $supportName, prompt: Text("Name (e.g. Mara)").foregroundColor(Dusk.muted(0.4)))
                .font(Dusk.sans(15)).foregroundStyle(Dusk.text)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassCard(fill: 0.05, cornerRadius: 14)
            TextField("", text: $supportNumber, prompt: Text("Phone number").foregroundColor(Dusk.muted(0.4)))
                .font(Dusk.sans(15)).foregroundStyle(Dusk.text)
                .keyboardType(.phonePad)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassCard(fill: 0.05, cornerRadius: 14)
            if showsNumberHint {
                Label("Add a number we can dial so the Call button appears on Grounding.", systemImage: "info.circle")
                    .font(Dusk.sans(11.5)).foregroundStyle(Dusk.peachLight.opacity(0.9))
                    .accessibilityHint("The support Call button needs a dialable number")
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 20)
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHECK-IN REMINDERS")
                .font(Dusk.sans(10.5, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))

            Toggle(isOn: $remindersEnabled) {
                Text("Gentle nudges to check in")
                    .font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.peach)
            .onChange(of: remindersEnabled) { _, enabled in
                if enabled { NotificationManager.requestAuthorization() }
                NotificationManager.refresh(isLive: hasLiveExperience)
            }

            if remindersEnabled {
                Text("Every")
                    .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.5))
                SegmentedToggle(options: ["60 min", "90 min", "120 min"], selection: intervalIndex)
                    .onChange(of: reminderIntervalMinutes) { _, _ in
                        NotificationManager.refresh(isLive: hasLiveExperience)
                    }
            }

            Text("Reminders only arrive while an experience is live, and stop when you end it.")
                .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5)).lineSpacing(1)
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.05, cornerRadius: 20)
    }

    private var privacyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield").font(.system(size: 20)).foregroundStyle(Dusk.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stored on device").font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                Text("Your journal never leaves this iPhone.").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.55))
            }
            Spacer()
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .glassCard(fill: 0.05, cornerRadius: 20)
    }

    private var exportAllCard: some View {
        ShareLink(item: allMarkdown) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 18)).foregroundStyle(Dusk.peach)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export everything").font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                    Text("All experiences as a single Markdown file.").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Dusk.muted(0.4))
            }
            .padding(.horizontal, 17).padding(.vertical, 16)
            .glassCard(fill: 0.05, cornerRadius: 20)
        }
        .disabled(finished.isEmpty)
        .opacity(finished.isEmpty ? 0.5 : 1)
        .accessibilityLabel("Export everything")
        .accessibilityHint(finished.isEmpty
            ? "Available once you've finished an experience"
            : "Shares all experiences as a single Markdown file")
    }

    private var aboutCard: some View {
        Text("Botanic is a private supplement & experience journal. It is user-authored and descriptive — it offers no doses and no guidance, and it is not medical advice.")
            .font(Dusk.serifItalic(13.5)).foregroundStyle(Dusk.muted(0.6)).lineSpacing(2)
            .padding(.horizontal, 17).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(fill: 0.04, cornerRadius: 18)
    }

    private var allMarkdown: String {
        finished.map(MarkdownExport.experience).joined(separator: "\n\n\n")
    }
}
