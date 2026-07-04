import BotanicKit
import SwiftUI

/// Two steps: a compact native confirmation, then a full-screen "Experience complete" celebration
/// (design handoff §07) where an on-device model drafts a title/subtitle while the user watches, both
/// editable before they commit. Ending only happens when the user taps "Save to history" — "Keep it
/// running" leaves the experience untouched and cancels the in-flight generation.
struct EndExperienceView: View {
    var experience: Experience
    var summarizer: any ExperienceSummarizing = OnDeviceExperienceSummarizer()
    var onSave: (_ title: String, _ subtitle: String?, _ titleSource: TitleSource, _ feltWords: [String]) -> Void
    var onKeepRunning: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .confirm
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var isGenerating = false
    @State private var userEdited = false
    @State private var feltWords: [String] = []
    @State private var generationTask: Task<Void, Never>?

    @State private var orbScale: CGFloat = 0.6
    @State private var contentOpacity: Double = 0
    @State private var rippleVisible = false
    @State private var petalsFallen = false
    @State private var sparklePulse = false

    enum Phase { case confirm, complete }

    private static let petalPalette: [Color] = [Dusk.peach, Dusk.pink, Dusk.lavender]

    var body: some View {
        ZStack {
            DuskBackground(live: true)
            switch phase {
            case .confirm: confirmCard
            case .complete: completeScreen
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Confirm

    private var confirmCard: some View {
        VStack {
            VStack(spacing: 6) {
                SectionLabel(title: experience.title, color: Dusk.pinkSoft)
                Text(experience.duration().botanicDuration)
                    .font(Dusk.serif(40, .light))
                    .foregroundStyle(Dusk.muted(0.7))
                Text("still settling")
                    .font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.42))
            }
            .padding(.top, 80)
            .opacity(0.6)

            Spacer()

            VStack(spacing: 0) {
                Text("End this experience?")
                    .font(Dusk.serif(25, .medium)).foregroundStyle(Dusk.text)
                    .padding(.bottom, 10)
                Text("Your timeline keeps running quietly in the background. You can step away and come back any time tonight — no need to close it out.")
                    .font(Dusk.serifItalic(16)).foregroundStyle(Dusk.muted(0.66))
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.bottom, 18)

                HStack(spacing: 11) {
                    Image(systemName: "clock").foregroundStyle(Dusk.peach)
                    Text("Ending drafts an on-device summary and writes tonight to your history.")
                        .font(Dusk.sans(13)).foregroundStyle(Dusk.muted(0.72))
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
                .glassCard(fill: 0.05, cornerRadius: 16)
                .padding(.bottom, 18)

                HStack(spacing: 11) {
                    Button("Not yet") { dismiss() }
                        .buttonStyle(DuskSoftButton())
                    Button("End experience") {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .complete }
                        beginGeneration()
                    }
                    .buttonStyle(DuskPrimaryButton(height: 54))
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Dusk.peachLight.opacity(0.18), lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.bottom, 20)
        }
    }

    // MARK: Complete

    private var completeScreen: some View {
        ZStack {
            celebration

            ScrollView {
                VStack(spacing: 22) {
                    orbSpacer

                    VStack(spacing: 10) {
                        SectionLabel(title: "Experience complete", color: Dusk.pinkSoft)
                        Text(experience.duration().botanicDuration)
                            .font(Dusk.serif(44, .light))
                            .foregroundStyle(Dusk.text)
                        Text(metaLine)
                            .font(Dusk.sans(13))
                            .foregroundStyle(Dusk.muted(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)

                    summaryCard

                    if !feltWords.isEmpty {
                        FlowLayout(spacing: 9) {
                            ForEach(feltWords, id: \.self) { word in
                                Text(word.lowercased())
                                    .font(Dusk.serifItalic(15))
                                    .foregroundStyle(Dusk.text)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .glassCard(fill: 0.07, cornerRadius: 14)
                            }
                        }
                    }

                    VStack(spacing: 11) {
                        Button("Save to history") {
                            Haptics.success()
                            commit()
                        }
                        .buttonStyle(DuskPrimaryButton(height: 54))
                        .disabled(isGenerating && title.isEmpty)

                        Button("Keep it running") {
                            generationTask?.cancel()
                            onKeepRunning()
                            dismiss()
                        }
                        .font(Dusk.sans(14, .medium))
                        .foregroundStyle(Dusk.muted(0.6))
                        .padding(.top, 2)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .opacity(contentOpacity)
        }
        .onAppear { animateInCelebration() }
    }

    private var metaLine: String {
        let startClock = BotanicFormat.clock(experience.startedAt)
        let endClock = BotanicFormat.clock(experience.endedAt ?? Date())
        let supplementCount = experience.loggedSupplements.count
        let checkInCount = experience.checkIns.count
        let noteCount = experience.journalEntries.count
        var parts = ["\(startClock) – \(endClock)"]
        parts.append("\(supplementCount) supplement\(supplementCount == 1 ? "" : "s")")
        parts.append("\(checkInCount) check-in\(checkInCount == 1 ? "" : "s")")
        if noteCount > 0 {
            parts.append("\(noteCount) note\(noteCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("✦")
                    .opacity(reduceMotion ? 0.7 : (sparklePulse ? 1 : 0.55))
                Text("SUMMARY · DRAFTED ON YOUR DEVICE")
                    .font(Dusk.sans(10.5, .bold))
                    .tracking(1.6)
                    .foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            }

            if isGenerating {
                VStack(alignment: .leading, spacing: 10) {
                    shimmerBlock(width: 220, height: 26)
                    shimmerBlock(width: 260, height: 16)
                    shimmerBlock(width: 180, height: 16)
                }
                .accessibilityLabel("Drafting summary")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: $title, axis: .vertical)
                        .font(Dusk.serif(24, .medium))
                        .foregroundStyle(Dusk.text)
                        .onChange(of: title) { _, _ in userEdited = true }
                        .accessibilityLabel("Experience title, editable")
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Dusk.peach.opacity(0.6))
                        .frame(height: 1)
                }

                TextField("Subtitle", text: $subtitle,
                          prompt: Text("What happened tonight?").foregroundColor(Dusk.muted(0.4)),
                          axis: .vertical)
                    .font(Dusk.serifItalic(15))
                    .foregroundStyle(Dusk.muted(0.78))
                    .lineLimit(1...4)
                    .onChange(of: subtitle) { _, _ in userEdited = true }
                    .accessibilityLabel("Experience subtitle, editable")
            }

            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                Text("Tap anything to rewrite it — it's yours. Nothing leaves your phone.")
                    .font(Dusk.sans(11))
            }
            .foregroundStyle(Dusk.muted(0.45))
            .padding(.top, 2)
        }
        .padding(20)
        .warmGlassCard(cornerRadius: 22)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                sparklePulse = true
            }
        }
    }

    private func shimmerBlock(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.white.opacity(reduceMotion ? 0.09 : (sparklePulse ? 0.14 : 0.07)))
            .frame(width: width, height: height)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    sparklePulse = true
                }
            }
    }

    // MARK: Celebration (petals + orb + ripple)

    private var orbSpacer: some View {
        Color.clear.frame(width: 98, height: 98)
    }

    private var celebration: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<5, id: \.self) { i in
                    petal(index: i)
                }
                ripple
            }
            orb
        }
        .accessibilityHidden(true)
    }

    private var orb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(r: 251, g: 213, b: 194),
                        Color(r: 240, g: 160, b: 184),
                        Color(r: 192, g: 132, b: 252)
                    ],
                    center: .init(x: 0.42, y: 0.38),
                    startRadius: 0, endRadius: 62
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1).blur(radius: 1))
            .shadow(color: Color(r: 240, g: 160, b: 184, o: 0.4), radius: 22)
            .frame(width: 98, height: 98)
            .scaleEffect(orbScale)
            .offset(y: -240)
    }

    private var ripple: some View {
        Circle()
            .stroke(
                LinearGradient(colors: [Dusk.peach, Dusk.pink], startPoint: .top, endPoint: .bottom),
                lineWidth: 2
            )
            .frame(width: 98, height: 98)
            .scaleEffect(rippleVisible ? 2.4 : 0.6)
            .opacity(rippleVisible ? 0 : 0.55)
            .offset(y: -240)
    }

    private func petal(index: Int) -> some View {
        let color = Self.petalPalette[index % Self.petalPalette.count]
        let xOffset = CGFloat([-90, -40, 0, 45, 90][index % 5])
        let duration = Double([4.6, 5.2, 4.9, 5.6, 5.0][index % 5])
        let delay = Double(index) * 0.35

        return Ellipse()
            .fill(color.opacity(0.65))
            .frame(width: 13, height: 18)
            .offset(x: xOffset, y: petalsFallen ? 480 : -420)
            .rotationEffect(.degrees(petalsFallen ? Double(index) * 35 - 60 : 0))
            .animation(
                .easeIn(duration: duration).delay(delay).repeatForever(autoreverses: false),
                value: petalsFallen
            )
    }

    private func animateInCelebration() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                orbScale = 1
                contentOpacity = 1
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { orbScale = 1 }
            withAnimation(.easeOut(duration: 0.3)) { contentOpacity = 1 }
            withAnimation(.easeOut(duration: 3)) { rippleVisible = true }
            petalsFallen = true
        }
    }

    // MARK: Generation

    private func beginGeneration() {
        isGenerating = true
        feltWords = FeltWordSummary.top(
            from: experience.checkIns.sorted { $0.createdAt < $1.createdAt }.map(\.tags),
            limit: 3
        )
        let input = ExperienceStore.live.summaryInput(for: experience)
        let generator = summarizer
        generationTask = Task {
            let output: ExperienceSummaryOutput
            if let result = try? await generator.summarize(input) {
                output = result
            } else {
                output = DeterministicExperienceSummarizer.summarize(input)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                title = output.title
                subtitle = output.subtitle
                isGenerating = false
            }
        }
    }

    private func commit() {
        generationTask?.cancel()
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = finalTitle.isEmpty ? experience.title : finalTitle
        onSave(
            resolvedTitle,
            finalSubtitle.isEmpty ? nil : finalSubtitle,
            userEdited ? .user : .ai,
            feltWords
        )
    }
}
