import BotanicKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Experience.startedAt, order: .reverse) private var experiences: [Experience]

    @State private var selectedTab: AppTab = .today
    @State private var showingAdd = false
    @State private var showingCheckIn = false
    @State private var showingEnd = false
    @State private var showingNote = false
    @State private var pendingInsights = false
    @State private var didSeed = false
    @State private var historyPath: [Experience] = []
    /// Set by the Today idle screen's "Again tonight?" quick-add before showing the Add sheet, so
    /// the sheet can seed its draft from a past supplement. Cleared once the sheet dismisses.
    @State private var addPrefill: SupplementDraft?

    /// A bloom staged by a save closure but not yet promoted — held until its sheet's `showing*`
    /// flag transitions to `false`, so the bloom only appears once the sheet has actually dismissed.
    @State private var pendingBloom: BloomEvent?
    /// The bloom currently shown by the overlay, if any.
    @State private var bloomEvent: BloomEvent?

    private var liveExperience: Experience? {
        experiences.first { $0.endedAt == nil }
    }

    /// Launch-argument hooks used only for deterministic screenshots, e.g. `-initialTab history`,
    /// `-openSheet add|checkin|journal|end`, and `-openDetail` (most recent experience).
    private func applyScreenshotLaunchArgs() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-initialTab"), idx + 1 < args.count {
            switch args[idx + 1] {
            case "history": selectedTab = .history
            case "settings": selectedTab = .settings
            case "insights":
                selectedTab = .history
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pendingInsights = true }
            default: selectedTab = .today
            }
        }
        if args.contains("-openDetail") {
            selectedTab = .history
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let exp = ExperienceStore.mostRecentFinished(in: modelContext) {
                    historyPath = [exp]
                }
            }
        }
        if let idx = args.firstIndex(of: "-openSheet"), idx + 1 < args.count {
            let target = args[idx + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                switch target {
                case "add": showingAdd = true
                case "checkin": showingCheckIn = true
                case "journal", "note": showingNote = true
                case "end": showingEnd = true
                default: break
                }
            }
        }
    }

    /// Constrains each tab's content to a comfortable reading width and lets the dusk backdrop
    /// (set as the TabView's background) show through behind it.
    private func tabContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.clear)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tabContent {
                TodayView(
                    live: liveExperience,
                    onAdd: { showingAdd = true },
                    onQuickAdd: { draft in
                        addPrefill = draft
                        showingAdd = true
                    },
                    onCheckIn: { showingCheckIn = true },
                    onNote: { showingNote = true },
                    onEnd: { showingEnd = true }
                )
            }
            .tabItem { Label("Today", systemImage: "circle.fill") }
            .tag(AppTab.today)

            tabContent {
                NavigationStack(path: $historyPath) {
                    HistoryView(experiences: experiences, autoOpenInsights: $pendingInsights)
                        .navigationDestination(for: Experience.self) { exp in
                            ExperienceDetailView(experience: exp)
                        }
                }
            }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(AppTab.history)

            tabContent {
                NavigationStack {
                    SettingsView(experiences: experiences)
                }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(Dusk.peach)
        .background(DuskBackground(live: liveExperience != nil && selectedTab == .today))
        .ignoresSafeArea(.keyboard)
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            SampleData.seedIfRequested(into: modelContext, existing: experiences)
            applyScreenshotLaunchArgs()
        }
        // Keyed on the live experience so it runs once `@Query` resolves one (and again across
        // launches): re-attach to any surviving activity, then ensure one is running.
        .task(id: liveExperience?.id) {
            LiveActivityController.shared.adopt(liveExperienceID: liveExperience?.id)
            if let live = liveExperience { ExperienceStore.live.resumeLiveActivity(for: live) }
        }
        .onOpenURL { url in
            // botanic://checkin — opened from the Live Activity's "Check in" affordance.
            guard url.scheme == "botanic", url.host == "checkin", liveExperience != nil else { return }
            selectedTab = .today
            showingCheckIn = true
        }
        .sheet(isPresented: $showingAdd, onDismiss: { addPrefill = nil }) {
            AddSupplementView(hasLiveExperience: liveExperience != nil, initialDraft: addPrefill) { draft in
                let experience = ExperienceStore.live.addSupplement(draft, in: modelContext)
                pendingBloom = BloomEvent(
                    kind: .supplement(draft.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                    savedAt: Date(),
                    liveTitle: experience.title,
                    liveElapsed: experience.duration().botanicDuration
                )
                showingAdd = false
            }
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showingCheckIn) {
            if let live = liveExperience {
                CheckInView(experience: live) { draft in
                    ExperienceStore.live.addCheckIn(draft, to: live, in: modelContext)
                    pendingBloom = BloomEvent(
                        kind: .checkIn(draft.feeling.rawValue),
                        savedAt: Date(),
                        liveTitle: live.title,
                        liveElapsed: live.duration().botanicDuration
                    )
                    showingCheckIn = false
                }
                .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showingNote) {
            if let live = liveExperience {
                NoteView(experience: live) { text, kind, prompt in
                    ExperienceStore.live.addJournalEntry(text: text, kind: kind, prompt: prompt,
                                                    to: live, in: modelContext)
                    pendingBloom = BloomEvent(
                        kind: .note,
                        savedAt: Date(),
                        liveTitle: live.title,
                        liveElapsed: live.duration().botanicDuration
                    )
                    // NoteView dismisses itself via `dismiss()` after calling this closure, which
                    // flips `showingNote` to false and triggers the `.onChange` below.
                }
                .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showingEnd) {
            if let live = liveExperience {
                EndExperienceView(
                    experience: live,
                    onSave: { title, subtitle, titleSource, feltWords in
                        ExperienceStore.live.end(
                            live, title: title, subtitle: subtitle, titleSource: titleSource,
                            feltWords: feltWords, in: modelContext
                        )
                        showingEnd = false
                    },
                    onKeepRunning: { showingEnd = false }
                )
                .presentationBackground(.clear)
                .presentationDetents([.large])
            }
        }
        .onChange(of: showingAdd) { _, isPresented in promoteBloom(if: !isPresented) }
        .onChange(of: showingCheckIn) { _, isPresented in promoteBloom(if: !isPresented) }
        .onChange(of: showingNote) { _, isPresented in promoteBloom(if: !isPresented) }
        .overlay {
            if let event = bloomEvent {
                BloomMomentOverlay(event: event) {
                    withAnimation(.easeOut(duration: 0.3)) { bloomEvent = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }

    /// Promotes a staged bloom into the visible overlay once its sheet has actually dismissed,
    /// firing the single success haptic for the save at that moment (bloom-appearance now owns the
    /// only haptic per save — ad hoc haptics were removed from each sheet's own save action).
    private func promoteBloom(if dismissed: Bool) {
        guard dismissed, let event = pendingBloom else { return }
        pendingBloom = nil
        Haptics.success()
        withAnimation(.easeOut(duration: 0.25)) { bloomEvent = event }
    }
}
