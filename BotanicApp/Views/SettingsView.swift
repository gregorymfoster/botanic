import BotanicKit
import SwiftUI

struct SettingsView: View {
    var experiences: [Experience]
    @AppStorage(NotificationManager.enabledKey) private var remindersEnabled = true
    @AppStorage(NotificationManager.intervalKey) private var reminderIntervalMinutes = 90
    @State private var zipURL: URL?
    @State private var zipExportFailed = false

    private static let intervalOptions = [45, 60, 90, 120]

    private var finished: [Experience] {
        experiences.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    private var hasLiveExperience: Bool {
        experiences.contains { $0.endedAt == nil }
    }

    /// Bridges the 45/60/90/120-minute preference to the `SegmentedToggle`'s 0-based index.
    private var intervalIndex: Binding<Int> {
        Binding(
            get: { Self.intervalOptions.firstIndex(of: reminderIntervalMinutes) ?? 2 },
            set: { reminderIntervalMinutes = Self.intervalOptions[$0] }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
                SegmentedToggle(options: ["45 min", "60 min", "90 min", "120 min"], selection: intervalIndex)
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

    @ViewBuilder
    private var exportAllCard: some View {
        if let zipURL {
            ShareLink(item: zipURL) {
                exportAllRow
            }
            .disabled(finished.isEmpty)
            .opacity(finished.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Export everything")
            .accessibilityHint("Shares all experiences as a .zip of Markdown files")
            .onDisappear { self.zipURL = nil }
        } else {
            Button {
                generateZip()
            } label: {
                exportAllRow
            }
            .disabled(finished.isEmpty)
            .opacity(finished.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Export everything")
            .accessibilityHint(finished.isEmpty
                ? "Available once you've finished an experience"
                : "Builds a .zip of all experiences as Markdown files")
            .alert("Couldn't build the export", isPresented: $zipExportFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something went wrong creating the .zip. Try again in a moment.")
            }
        }
    }

    private var exportAllRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 18)).foregroundStyle(Dusk.peach)
            VStack(alignment: .leading, spacing: 2) {
                Text("Export everything").font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                Text("All experiences as Markdown files in a .zip.").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Dusk.muted(0.4))
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .glassCard(fill: 0.05, cornerRadius: 20)
    }

    private func generateZip() {
        do {
            zipURL = try MarkdownMirrorService.exportZipURL(experiences: experiences)
        } catch {
            zipExportFailed = true
        }
    }

    private var aboutCard: some View {
        Text("Botanic is a private supplement & experience journal. It is user-authored and descriptive — it offers no doses and no guidance, and it is not medical advice.")
            .font(Dusk.serifItalic(13.5)).foregroundStyle(Dusk.muted(0.6)).lineSpacing(2)
            .padding(.horizontal, 17).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(fill: 0.04, cornerRadius: 18)
    }
}
