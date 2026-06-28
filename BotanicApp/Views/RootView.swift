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
    @State private var showingGrounding = false
    @State private var pendingInsights = false
    @State private var didSeed = false
    @State private var historyPath: [Experience] = []
    @AppStorage("supportPersonNumber") private var supportNumber = ""

    private var liveExperience: Experience? {
        experiences.first { $0.endedAt == nil }
    }

    /// One-tap reach-out: dial the support person when one is saved, otherwise open the Grounding
    /// sheet (which holds the support setup path, emergency services, and the safety copy).
    private func reachSupport() {
        if PhoneDialer.canDial(supportNumber) {
            PhoneDialer.dial(supportNumber)
        } else {
            showingGrounding = true
        }
    }

    /// Launch-argument hooks used only for deterministic screenshots, e.g. `-initialTab history`,
    /// `-openSheet add|checkin|journal|end|grounding`, and `-openDetail` (most recent experience).
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
                case "grounding": showingGrounding = true
                default: break
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DuskBackground(live: liveExperience != nil && selectedTab == .today)

            Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        live: liveExperience,
                        onAdd: { showingAdd = true },
                        onCheckIn: { showingCheckIn = true },
                        onNote: { showingJournal = true },
                        onGround: { showingGrounding = true },
                        onSupport: reachSupport,
                        onEnd: { showingEnd = true }
                    )
                case .history:
                    NavigationStack(path: $historyPath) {
                        HistoryView(experiences: experiences, autoOpenInsights: $pendingInsights)
                            .navigationDestination(for: Experience.self) { exp in
                                ExperienceDetailView(experience: exp)
                            }
                    }
                case .settings:
                    NavigationStack {
                        SettingsView(experiences: experiences)
                    }
                }
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)

            DuskTabBar(selected: $selectedTab, live: liveExperience != nil)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            SampleData.seedIfRequested(into: modelContext, existing: experiences)
            applyScreenshotLaunchArgs()
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
        .sheet(isPresented: $showingGrounding) {
            GroundingView()
                .presentationBackground(.clear)
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
