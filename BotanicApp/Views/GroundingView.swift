import SwiftUI

struct GroundingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("supportPersonName") private var supportName = ""
    @AppStorage("supportPersonNumber") private var supportNumber = ""
    @State private var breathing = false

    var body: some View {
        SheetScaffold(
            title: "Grounding & safety",
            leading: .chevron,
            onLeading: { dismiss() }
        ) {
            ScrollView {
                VStack(spacing: 11) {
                    HStack(spacing: 10) {
                        breatheTile
                        stepsTileHeader
                    }

                    stepsCard
                    if !supportName.isEmpty && PhoneDialer.canDial(supportNumber) { supportButton }
                    emergencyButton

                    Text("Botanic is a private journaling app — not medical advice, and not for dosing or medical decisions. In an emergency, call your local emergency services.")
                        .font(Dusk.serifItalic(12.5)).foregroundStyle(Dusk.muted(0.5))
                        .multilineTextAlignment(.center).lineSpacing(2)
                        .padding(.top, 8).padding(.horizontal, 6)
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 28)
            }
        }
    }

    private var breatheTile: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(RadialGradient(colors: [Dusk.peachLight, Dusk.peach], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 44, height: 44)
                .scaleEffect(breathing ? 1.12 : 0.92)
                .shadow(color: Dusk.peach.opacity(0.5), radius: 14)
            Text("Breathe with me").font(Dusk.sans(13.5, .semibold)).foregroundStyle(Dusk.text)
            Text(breathing ? "breathe out…" : "breathe in…")
                .font(Dusk.serifItalic(12)).foregroundStyle(Dusk.muted(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .warmGlassCard()
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathing = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breathe with me. A slow in-and-out breathing guide.")
    }

    private var stepsTileHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.hexagonpath").font(.system(size: 24)).foregroundStyle(Dusk.lavender)
            Text("Grounding steps").font(Dusk.sans(13.5, .semibold)).foregroundStyle(Dusk.text)
            Text("5-4-3-2-1").font(Dusk.serifItalic(12)).foregroundStyle(Dusk.muted(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .glassCard(fill: 0.05, cornerRadius: 18)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IF THINGS FEEL INTENSE")
                .font(Dusk.sans(11, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft.opacity(0.85))
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(spacing: 11) {
                    Text("\(i + 1)").font(Dusk.serif(15)).foregroundStyle(Dusk.peach).frame(width: 18)
                    Text(step).font(Dusk.sans(13.5)).foregroundStyle(Dusk.muted(0.86))
                }
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(fill: 0.045, cornerRadius: 18)
    }

    private let steps = [
        "Feel your feet on the floor",
        "Name five things you can see",
        "Sip water · slow your breath",
        "Reach out to your support person"
    ]

    private var supportButton: some View {
        Button { PhoneDialer.dial(supportNumber) } label: {
            HStack(spacing: 13) {
                iconBox("phone", Dusk.mint, Dusk.mint.opacity(0.18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Call \(supportName)").font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                    Text("Your support person").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 17).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Dusk.mint.opacity(0.16), Dusk.mint.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Dusk.mint.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emergencyButton: some View {
        Button { PhoneDialer.dial("911") } label: {
            HStack(spacing: 13) {
                iconBox("exclamationmark.triangle", Dusk.danger, Dusk.danger.opacity(0.2))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Call emergency services").font(Dusk.sans(15, .semibold)).foregroundStyle(Dusk.text)
                    Text("If you or someone feels at risk").font(Dusk.sans(12)).foregroundStyle(Dusk.muted(0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 17).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Dusk.danger.opacity(0.18), Dusk.danger.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Dusk.danger.opacity(0.34), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func iconBox(_ icon: String, _ tint: Color, _ bg: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(bg).frame(width: 40, height: 40)
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }
}
