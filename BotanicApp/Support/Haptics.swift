import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Light, native haptic feedback for the app's key moments. Wraps UIKit's feedback generators so call
/// sites stay one-liners; no-ops where UIKit isn't available. Used sparingly — committing actions and
/// discrete selections only, never on every tap.
@MainActor
enum Haptics {
    /// A committing action landed — a supplement logged, a check-in or experience saved.
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// A discrete selection changed — toggling a tag or feeling word.
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// A light tap for smaller confirmations — sending a note, advancing a step.
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
