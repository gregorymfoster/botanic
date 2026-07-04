import BotanicKit
import Foundation
import SwiftData

/// Seeds illustrative data so History, Insights, and the live Today screen can be exercised and
/// screenshotted. Gated behind a launch argument so it never runs for real users.
///
/// `-seedSampleData` seeds a body of finished experiences plus one live experience.
/// `-seedSampleHistory` seeds only finished experiences (idle Today).
enum SampleData {
    static func seedIfRequested(into context: ModelContext, existing: [Experience]) {
        let args = ProcessInfo.processInfo.arguments
        let wantsFull = args.contains("-seedSampleData")
        let wantsHistory = args.contains("-seedSampleHistory")
        guard wantsFull || wantsHistory, existing.isEmpty else { return }

        seedHistory(into: context)
        if wantsFull { seedLive(into: context) }
        seedLibrary(into: context)
        try? context.save()
    }

    /// Seeds a few remembered supplements consistent with the seeded supplement entries above, so
    /// the quick-add UI has data to prefill from.
    private static func seedLibrary(into context: ModelContext) {
        let now = Date()
        let items = [
            SupplementLibraryItem(name: "Magnesium glycinate", lastAmount: "2 capsules with water",
                                  lastIntention: "A calmer evening and deeper sleep.",
                                  useCount: 7, lastUsedAt: now.addingTimeInterval(-2 * 3600)),
            SupplementLibraryItem(name: "Chamomile tea", lastAmount: "1 mug, warm",
                                  lastIntention: nil, useCount: 6, lastUsedAt: now.addingTimeInterval(-48 * 60)),
            SupplementLibraryItem(name: "L-theanine", lastAmount: "1 capsule",
                                  lastIntention: "Steadier focus without the edge.",
                                  useCount: 4, lastUsedAt: now.addingTimeInterval(-25 * 60))
        ]
        for item in items { context.insert(item) }
    }

    private static func seedLive(into context: ModelContext) {
        let now = Date()
        let exp = Experience(title: "Evening at home",
                             startedAt: now.addingTimeInterval(-2 * 3600 - 14 * 60),
                             locationContext: "Home")
        context.insert(exp)

        let mag = SupplementEntry(name: "Magnesium glycinate", howTaking: "2 capsules with water",
                                  intention: "A calmer evening and deeper sleep.",
                                  takenAt: exp.startedAt, status: .taken, colorIndex: 0)
        let tea = SupplementEntry(name: "Chamomile tea", howTaking: "1 mug, warm",
                                  takenAt: now.addingTimeInterval(-48 * 60), status: .taken, colorIndex: 1)
        let theanine = SupplementEntry(name: "L-theanine", howTaking: "1 capsule",
                                       takenAt: nil, scheduledFor: now.addingTimeInterval(25 * 60),
                                       status: .scheduled, colorIndex: 2)
        for s in [mag, tea, theanine] { s.experience = exp; context.insert(s) }

        let checkIn = CheckIn(createdAt: now.addingTimeInterval(-26 * 60),
                              valence: 0.7, intensity: 0.38, bodyLoad: 0.28,
                              feeling: .settled, tags: ["Grounded", "Calm"])
        checkIn.experience = exp
        context.insert(checkIn)

        let entries = [
            JournalEntry(createdAt: now.addingTimeInterval(-86 * 60), kind: .note,
                         text: "Shoulders dropping. The flat feels quiet and kind tonight."),
            JournalEntry(createdAt: now.addingTimeInterval(-50 * 60), kind: .oneWord, text: "Steady")
        ]
        for e in entries { e.experience = exp; context.insert(e) }
    }

    private static func seedHistory(into context: ModelContext) {
        let cal = Calendar.current
        let base = Date()

        for spec in specs {
            guard let start = cal.date(byAdding: .day, value: -spec.daysAgo, to: base) else { continue }
            let exp = Experience(title: spec.title,
                                 subtitle: spec.subtitle,
                                 startedAt: start,
                                 endedAt: start.addingTimeInterval(spec.minutes * 60),
                                 locationContext: spec.location,
                                 titleSource: spec.subtitle == nil ? .user : .ai,
                                 feltWords: spec.feltWords)
            exp.feltSummary = spec.feeling
            exp.noteToFuture = spec.note
            context.insert(exp)

            for (i, name) in spec.supplements.enumerated() {
                let s = SupplementEntry(name: name, takenAt: start.addingTimeInterval(Double(i) * 1200),
                                        status: .taken, colorIndex: i)
                s.experience = exp
                context.insert(s)
            }
            for c in 0..<spec.checkIns {
                let ci = CheckIn(createdAt: start.addingTimeInterval(Double(c + 1) * 1800),
                                 valence: spec.feeling.valence, feeling: spec.feeling)
                ci.experience = exp
                context.insert(ci)
            }
            if let word = spec.oneWord {
                let j = JournalEntry(createdAt: start.addingTimeInterval(900), kind: .oneWord, text: word)
                j.experience = exp
                context.insert(j)
            }
        }
    }

    private struct Spec {
        let daysAgo: Int
        let title: String
        let subtitle: String?
        let minutes: Double
        let location: String
        let feeling: FeelingWord
        let supplements: [String]
        let checkIns: Int
        let oneWord: String?
        let note: String?
        let feltWords: [String]

        init(daysAgo: Int, title: String, subtitle: String? = nil, minutes: Double, location: String,
             feeling: FeelingWord, supplements: [String], checkIns: Int, oneWord: String?, note: String?,
             feltWords: [String] = []) {
            self.daysAgo = daysAgo
            self.title = title
            self.subtitle = subtitle
            self.minutes = minutes
            self.location = location
            self.feeling = feeling
            self.supplements = supplements
            self.checkIns = checkIns
            self.oneWord = oneWord
            self.note = note
            self.feltWords = feltWords
        }
    }

    private static let specs: [Spec] = [
        Spec(daysAgo: 54, title: "Evening at home", subtitle: "A quiet wind-down with tea and magnesium",
             minutes: 160, location: "Home", feeling: .settled,
             supplements: ["Magnesium glycinate", "Chamomile tea", "L-theanine"], checkIns: 3, oneWord: "Steady",
             note: "The tea + a quiet room was the right combination. 3 check-ins felt like enough.",
             feltWords: ["Steady", "Warm", "Settled"]),
        Spec(daysAgo: 76, title: "Sunday slow morning", subtitle: "Garden light and chamomile",
             minutes: 110, location: "Garden", feeling: .warm,
             supplements: ["Magnesium glycinate", "Chamomile tea"], checkIns: 2, oneWord: "Warm", note: nil,
             feltWords: ["Warm", "Open"]),
        Spec(daysAgo: 117, title: "After the long walk", minutes: 55, location: "Out", feeling: .luminous,
             supplements: ["L-theanine"], checkIns: 1, oneWord: "Open", note: nil),
        Spec(daysAgo: 140, title: "Evening at home", minutes: 145, location: "Home", feeling: .calm,
             supplements: ["Magnesium glycinate", "Chamomile tea"], checkIns: 3, oneWord: "Calm", note: nil),
        Spec(daysAgo: 165, title: "Quiet Friday", minutes: 130, location: "Home", feeling: .settled,
             supplements: ["Magnesium glycinate", "Chamomile tea", "L-theanine"], checkIns: 4, oneWord: "Settled", note: nil),
        Spec(daysAgo: 190, title: "Restless night", minutes: 90, location: "Home", feeling: .restless,
             supplements: ["Magnesium glycinate"], checkIns: 2, oneWord: "Restless", note: nil),
        Spec(daysAgo: 210, title: "Garden afternoon", minutes: 100, location: "Garden", feeling: .grateful,
             supplements: ["Chamomile tea"], checkIns: 2, oneWord: "Grateful", note: nil),
        Spec(daysAgo: 232, title: "Evening at home", minutes: 150, location: "Home", feeling: .settled,
             supplements: ["Magnesium glycinate", "Chamomile tea"], checkIns: 3, oneWord: "Settled", note: nil),
        Spec(daysAgo: 255, title: "Out with friends", minutes: 70, location: "Out", feeling: .tired,
             supplements: ["L-theanine"], checkIns: 1, oneWord: "Tired", note: nil),
        Spec(daysAgo: 270, title: "Slow morning", minutes: 120, location: "Home", feeling: .clear,
             supplements: ["Magnesium glycinate"], checkIns: 2, oneWord: "Clear", note: nil),
        Spec(daysAgo: 285, title: "Evening at home", minutes: 135, location: "Home", feeling: .calm,
             supplements: ["Magnesium glycinate", "Chamomile tea", "L-theanine"], checkIns: 3, oneWord: "Calm", note: nil),
        Spec(daysAgo: 300, title: "First quiet night", minutes: 95, location: "Home", feeling: .tender,
             supplements: ["Chamomile tea"], checkIns: 2, oneWord: "Tender", note: nil)
    ]
}
