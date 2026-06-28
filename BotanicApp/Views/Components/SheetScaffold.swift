import SwiftUI

/// Wraps sheet content in a native navigation bar over the dusk backdrop (the sheets use
/// `.presentationBackground(.clear)` so each provides its own background). The bar is transparent
/// with a Spectral serif inline title (themed in `Dusk.applyControlAppearance()`); leading is a
/// Cancel / chevron dismiss, trailing an optional primary action.
struct SheetScaffold<Content: View>: View {
    var title: String
    var leading: LeadingStyle = .cancel
    var trailingTitle: String?
    var trailingEnabled: Bool = true
    var onLeading: () -> Void
    var onTrailing: (() -> Void)?
    @ViewBuilder var content: Content

    enum LeadingStyle: Equatable { case cancel, chevron, none }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DuskBackground().ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if leading != .none {
                        ToolbarItem(placement: .topBarLeading) { leadingControl }
                    }
                    if let trailingTitle, let onTrailing {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: onTrailing) {
                                Text(trailingTitle).font(Dusk.sans(14, .semibold))
                            }
                            .tint(Dusk.pinkSoft)
                            .disabled(!trailingEnabled)
                        }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var leadingControl: some View {
        switch leading {
        case .cancel:
            Button("Cancel", action: onLeading)
                .font(Dusk.sans(15))
                .tint(Dusk.muted(0.6))
        case .chevron:
            Button(action: onLeading) {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
            }
            .tint(Dusk.text)
        case .none:
            EmptyView()
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
