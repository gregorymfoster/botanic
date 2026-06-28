import BotanicKit
import SwiftUI

/// Renders a single moment on an experience timeline — shared by the live Journal sheet and the
/// read-only history detail view. Driven entirely by `TimelineEntry`'s display fields, so it knows
/// nothing about SwiftData.
struct TimelineRow: View {
    var entry: TimelineEntry
    var isLast: Bool

    private var offsetLabel: String {
        let total = Int(entry.offset)
        return String(format: "%d:%02d", total / 3600, (total % 3600) / 60)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 6) {
                Text(offsetLabel)
                    .font(Dusk.sans(11, .bold))
                    .foregroundStyle(Dusk.peach)
                if !isLast {
                    Rectangle()
                        .fill(LinearGradient(colors: [Dusk.peach.opacity(0.4), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 34)
            .padding(.top, 4)
            .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var content: some View {
        switch entry.kind {
        case .supplement(let name, let howTaking):
            card(warm: true) {
                Text("SUPPLEMENT STARTED")
                    .font(Dusk.sans(10, .bold)).tracking(1.4).foregroundStyle(Dusk.pinkSoft)
                Text("\(name)\(howTaking.map { " · \($0)" } ?? "")")
                    .font(Dusk.serif(16)).foregroundStyle(Dusk.text)
            }
        case .checkIn(let word):
            card(warm: true) {
                Text("ONE WORD FOR NOW")
                    .font(Dusk.sans(10, .bold)).tracking(1.6).foregroundStyle(Dusk.pinkSoft)
                Text("\(word).")
                    .font(Dusk.serif(22)).foregroundStyle(Dusk.text)
            }
        case .journal(let text, let isOneWord):
            card(warm: false) {
                if isOneWord {
                    Text("\(text).").font(Dusk.serif(22)).foregroundStyle(Dusk.text)
                } else {
                    Text(text)
                        .font(Dusk.serifItalic(15.5)).foregroundStyle(Dusk.text).lineSpacing(2)
                }
            }
        }
    }

    /// A spoken description that leads with the elapsed time, then the moment.
    private var accessibilityText: String {
        let total = Int(entry.offset)
        let h = total / 3600, m = (total % 3600) / 60
        let when = h > 0 ? "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s") in"
                         : "\(m) minute\(m == 1 ? "" : "s") in"
        switch entry.kind {
        case .supplement(let name, let howTaking):
            return "\(when). Supplement: \(name)\(howTaking.map { ", \($0)" } ?? "")"
        case .checkIn(let word):
            return "\(when). Check-in: felt \(word)"
        case .journal(let text, _):
            return "\(when). Journal: \(text)"
        }
    }

    private func card<C: View>(warm: Bool, @ViewBuilder _ inner: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) { inner() }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(TimelineCardBackground(warm: warm))
    }
}

private struct TimelineCardBackground: ViewModifier {
    var warm: Bool
    func body(content: Content) -> some View {
        if warm { content.warmGlassCard() } else { content.glassCard(fill: 0.06, cornerRadius: 18) }
    }
}
