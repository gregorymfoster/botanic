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
    @State private var showingJournal = false
    @State private var pendingInsights = false
    @State private var didSeed = false
    @State private var historyPath: [Experience] = []

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
                case "journal": showingJournal = true
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
                    onCheckIn: { showingCheckIn = true },
                    onNote: { showingJournal = true },
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
            if let live = liveExperience { ExperienceStore.resumeLiveActivity(for: live) }
        }
        .onOpenURL { url in
            // botanic://checkin — opened from the Live Activity's "Check in" affordance.
            guard url.scheme == "botanic", url.host == "checkin", liveExperience != nil else { return }
            selectedTab = .today
            showingCheckIn = true
        }
        .sheet(isPresented: $showingAdd) {
            AddSupplementView(hasLiveExperience: liveExperience != nil) { draft in
                ExperienceStore.addSupplement(draft, in: modelContext)
                showingAdd = false
            }
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showingCheckIn) {
            if let live = liveExperience {
                CheckInView(experience: live) { draft in
                    ExperienceStore.addCheckIn(draft, to: live, in: modelContext)
                    showingCheckIn = false
                }
                .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showingJournal) {
            if let live = liveExperience {
                JournalView(experience: live) { text, kind, prompt in
                    ExperienceStore.addJournalEntry(text: text, kind: kind, prompt: prompt,
                                                    to: live, in: modelContext)
                }
                .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showingEnd) {
            if let live = liveExperience {
                EndExperienceView(experience: live) { reflection in
                    ExperienceStore.end(live, reflection: reflection, in: modelContext)
                    showingEnd = false
                }
                .presentationBackground(.clear)
                .presentationDetents([.large])
            }
        }
    }
}
