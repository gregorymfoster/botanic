import SwiftUI

/// Wraps sheet content in the dusk backdrop with a consistent header bar (the sheets use
/// `.presentationBackground(.clear)` so each provides its own background). Leading is a Cancel /
/// chevron, center a serif title, trailing an optional primary action.
struct SheetScaffold<Content: View>: View {
    var title: String
    var leading: LeadingStyle = .cancel
    var trailingTitle: String?
    var trailingEnabled: Bool = true
    var onLeading: () -> Void
    var onTrailing: (() -> Void)?
    @ViewBuilder var content: Content

    enum LeadingStyle { case cancel, chevron, none }

    var body: some View {
        ZStack {
            DuskBackground()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                content
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(Dusk.serif(18))
                .foregroundStyle(Dusk.text)

            HStack {
                leadingControl
                Spacer()
                if let trailingTitle, let onTrailing {
                    Button(action: onTrailing) {
                        Text(trailingTitle)
                            .font(Dusk.sans(14, .semibold))
                            .foregroundStyle(trailingEnabled ? Dusk.pinkSoft : Dusk.muted(0.3))
                    }
                    .disabled(!trailingEnabled)
                }
            }
        }
    }

    @ViewBuilder private var leadingControl: some View {
        switch leading {
        case .cancel:
            Button(action: onLeading) {
                Text("Cancel").font(Dusk.sans(15)).foregroundStyle(Dusk.muted(0.6))
            }
        case .chevron:
            Button(action: onLeading) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Dusk.text)
                    .frame(width: 38, height: 38)
                    .glassCard(fill: 0.07, cornerRadius: 19)
            }
        case .none:
            Color.clear.frame(width: 38, height: 1)
        }
    }
}

/// A labeled glass field block used in editor sheets: an uppercase pink label over content.
struct FieldBlock<Content: View>: View {
    var label: String
    var labelColor: Color = Dusk.pinkSoft.opacity(0.85)
    var warm: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(Dusk.sans(10.5, .bold))
                .tracking(1.6)
                .foregroundStyle(labelColor)
            content
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FieldBackground(warm: warm))
    }
}

private struct FieldBackground: ViewModifier {
    var warm: Bool
    func body(content: Content) -> some View {
        if warm {
            content.warmGlassCard()
        } else {
            content.glassCard(fill: 0.05, cornerRadius: 18)
        }
    }
}
