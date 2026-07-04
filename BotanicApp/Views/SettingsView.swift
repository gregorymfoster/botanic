import BotanicKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    var experiences: [Experience]

    @AppStorage(NotificationManager.enabledKey) private var remindersEnabled = true
    @AppStorage(NotificationManager.intervalKey) private var reminderIntervalMinutes = 90
    @AppStorage(NotificationManager.supplementAlertsEnabledKey) private var supplementAlertsEnabled = true
    @AppStorage(NotificationManager.quietSuggestEnabledKey) private var quietSuggestEnabled = true
    @AppStorage(NotificationManager.quietSuggestHoursKey) private var quietSuggestHours = 3

    @AppStorage(BackupManager.icloudBackupEnabledKey) private var icloudBackupEnabled = true
    @AppStorage(MarkdownMirrorService.mirrorEnabledKey) private var mirrorEnabled = true
    @AppStorage(MarkdownMirrorService.fileNamingPatternKey) private var fileNamingPatternRaw = MarkdownFilePattern.dateTitle.rawValue

    @State private var mirrorFolderURL: URL?
    @State private var showingFolderImporter = false
    @State private var folderPickFailed = false

    @State private var zipURL: URL?
    @State private var zipExportFailed = false

    private static let intervalOptions = [45, 60, 90, 120]
    /// The "suggest ending after quiet" control folds the enabled flag and the hour threshold into a
    /// single picker (0 = off) so there's no dead chevron when the feature is off.
    private static let quietSuggestOptions = [0, 2, 3, 4]

    private var finished: [Experience] {
        experiences.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    private var hasLiveExperience: Bool {
        experiences.contains { $0.endedAt == nil }
    }

    private var fileNamingPattern: MarkdownFilePattern {
        MarkdownFilePattern(rawValue: fileNamingPatternRaw) ?? .dateTitle
    }

    private var intervalBinding: Binding<Int> {
        Binding(get: { reminderIntervalMinutes }, set: { newValue in
            reminderIntervalMinutes = newValue
            NotificationManager.live.refresh(isLive: hasLiveExperience)
        })
    }

    /// Bridges `quietSuggestEnabled` + `quietSuggestHours` to one selection: 0 means "Off".
    private var quietSuggestBinding: Binding<Int> {
        Binding(
            get: { quietSuggestEnabled ? quietSuggestHours : 0 },
            set: { newValue in
                if newValue == 0 {
                    quietSuggestEnabled = false
                } else {
                    quietSuggestEnabled = true
                    quietSuggestHours = newValue
                }
                // No `lastEventAt` is available here (that lives on the live experience's event
                // timeline, not in Settings) — the new threshold takes effect starting from the next
                // logged event on the live experience, not retroactively.
            }
        )
    }

    @Environment(\.modelContext) private var modelContext

    private var fileNamingBinding: Binding<MarkdownFilePattern> {
        Binding(
            get: { fileNamingPattern },
            set: { newValue in
                fileNamingPatternRaw = newValue.rawValue
                MarkdownMirrorService.syncAll(experiences: experiences, in: modelContext)
            }
        )
    }

    var body: some View {
        List {
            liveSection
            dataSection
            privacySection
            footerSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // Own backdrop: the iOS 26 TabView doesn't let RootView's shared background show through.
        .background(DuskBackground().ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { mirrorFolderURL = MarkdownMirrorService.resolveFolder() }
        .fileImporter(isPresented: $showingFolderImporter, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try MarkdownMirrorService.setFolder(url)
                    mirrorFolderURL = url
                    MarkdownMirrorService.syncAll(experiences: experiences, in: modelContext)
                } catch {
                    folderPickFailed = true
                }
            case .failure:
                folderPickFailed = true
            }
        }
        .alert("Couldn't use that folder", isPresented: $folderPickFailed) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityID.Settings.folderPickFailedOK)
        } message: {
            Text("Something went wrong saving access to that folder. Try choosing it again.")
        }
        .alert("Couldn't build the export", isPresented: $zipExportFailed) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityID.Settings.zipExportFailedOK)
        } message: {
            Text("Something went wrong creating the .zip. Try again in a moment.")
        }
    }

    // MARK: - Section 1 — While an experience is live

    private var liveSection: some View {
        Section {
            Toggle(isOn: $remindersEnabled) {
                Text("Check-in nudges").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.peach)
            .onChange(of: remindersEnabled) { _, enabled in
                if enabled { NotificationManager.live.requestAuthorization() }
                NotificationManager.live.refresh(isLive: hasLiveExperience)
            }
            .accessibilityHint("Soft haptic and lock screen glow while an experience is live")
            .accessibilityIdentifier(AccessibilityID.Settings.checkInNudgesToggle)

            Picker(selection: intervalBinding) {
                ForEach(Self.intervalOptions, id: \.self) { minutes in
                    Text("Every \(minutes) min").tag(minutes)
                }
            } label: {
                Text("Rhythm").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.muted(0.6))
            .accessibilityIdentifier(AccessibilityID.Settings.rhythmPicker)

            Toggle(isOn: $supplementAlertsEnabled) {
                Text("Scheduled supplement alerts").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.peach)
            .accessibilityIdentifier(AccessibilityID.Settings.supplementAlertsToggle)

            Picker(selection: quietSuggestBinding) {
                Text("Off").tag(0)
                ForEach(Self.quietSuggestOptions.filter { $0 != 0 }, id: \.self) { hours in
                    Text("\(hours) hours").tag(hours)
                }
            } label: {
                Text("Suggest ending after quiet").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.muted(0.6))
            .accessibilityIdentifier(AccessibilityID.Settings.quietSuggestPicker)
        } header: {
            SectionLabel(title: "While an experience is live")
        } footer: {
            Text("Nudges are a soft haptic and a glow on the lock screen — never a loud notification.")
                .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5)).lineSpacing(1)
        }
        .listRowBackground(rowBackground)
        .listRowSeparatorTint(Dusk.glassStroke.opacity(0.6))
    }

    // MARK: - Section 2 — Your data

    private var dataSection: some View {
        Section {
            Toggle(isOn: $icloudBackupEnabled) {
                Text("iCloud backup").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.mint)
            .onChange(of: icloudBackupEnabled) { _, _ in BackupManager.apply() }
            .accessibilityIdentifier(AccessibilityID.Settings.icloudBackupToggle)

            Toggle(isOn: $mirrorEnabled) {
                Text("Mirror journal files to a folder").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.mint)
            .onChange(of: mirrorEnabled) { _, enabled in
                if enabled, mirrorFolderURL != nil {
                    MarkdownMirrorService.syncAll(experiences: experiences, in: modelContext)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.mirrorEnabledToggle)

            Button {
                showingFolderImporter = true
            } label: {
                HStack {
                    Text("Folder").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
                    Spacer()
                    Text(mirrorFolderURL?.lastPathComponent ?? "Choose…")
                        .font(Dusk.sans(14)).foregroundStyle(Dusk.muted(0.5))
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Dusk.muted(0.35))
                }
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Folder")
            .accessibilityValue(mirrorFolderURL?.lastPathComponent ?? "Not chosen")
            .accessibilityHint("Choose the folder journal files mirror to")
            .accessibilityIdentifier(AccessibilityID.Settings.folderPicker)

            Picker(selection: fileNamingBinding) {
                ForEach(MarkdownFilePattern.allCases, id: \.self) { pattern in
                    Text(pattern.example).tag(pattern)
                }
            } label: {
                Text("File naming").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
            }
            .tint(Dusk.muted(0.6))
            .accessibilityIdentifier(AccessibilityID.Settings.fileNamingPicker)

            exportRow
        } header: {
            SectionLabel(title: "Your data")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("iCloud backup is included with your iPhone's normal backup — it isn't a live sync across your devices. Mirroring writes a Markdown file per experience to a folder you choose, which iCloud Drive can then sync however you've set it up.")
                Text("Example: \(fileNamingPattern.example)")
                    .font(Dusk.sans(11, .medium)).foregroundStyle(Dusk.muted(0.55))
                    .monospaced()
            }
            .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5)).lineSpacing(1)
        }
        .listRowBackground(rowBackground)
        .listRowSeparatorTint(Dusk.glassStroke.opacity(0.6))
    }

    @ViewBuilder
    private var exportRow: some View {
        if let zipURL {
            ShareLink(item: zipURL) {
                exportRowLabel
            }
            .disabled(finished.isEmpty)
            .opacity(finished.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Export everything")
            .accessibilityHint("Shares all experiences as a .zip of Markdown files")
            .accessibilityIdentifier(AccessibilityID.Settings.exportZip)
            .onDisappear { self.zipURL = nil }
        } else {
            Button {
                generateZip()
            } label: {
                exportRowLabel
            }
            .buttonStyle(.plain)
            .disabled(finished.isEmpty)
            .opacity(finished.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Export everything")
            .accessibilityHint(finished.isEmpty
                ? "Available once you've finished an experience"
                : "Builds a .zip of all experiences as Markdown files")
            .accessibilityIdentifier(AccessibilityID.Settings.exportZip)
        }
    }

    private var exportRowLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 16)).foregroundStyle(Dusk.peach)
            Text("Export everything as .zip").font(Dusk.sans(15)).foregroundStyle(Dusk.peach)
            Spacer()
        }
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

    private func generateZip() {
        do {
            zipURL = try MarkdownMirrorService.exportZipURL(experiences: experiences)
        } catch {
            zipExportFailed = true
        }
    }

    // MARK: - Section 3 — Privacy

    private var privacySection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield").font(.system(size: 18)).foregroundStyle(Dusk.mint)
                Text("On-device intelligence").font(Dusk.sans(15)).foregroundStyle(Dusk.text)
                Spacer()
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
        } header: {
            SectionLabel(title: "Privacy")
        } footer: {
            Text("Titles, summaries and word suggestions come from a small model on your phone — always on, nothing to configure, nothing ever leaves the device.")
                .font(Dusk.sans(11.5)).foregroundStyle(Dusk.muted(0.5)).lineSpacing(1)
        }
        .listRowBackground(rowBackground)
        .listRowSeparatorTint(Dusk.glassStroke.opacity(0.6))
    }

    // MARK: - Footer

    private var footerSection: some View {
        Section {
            Text("Botanic 2.0 · a private journal, not medical advice")
                .font(Dusk.serifItalic(13.5))
                .foregroundStyle(Dusk.muted(0.55))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
    }
}
