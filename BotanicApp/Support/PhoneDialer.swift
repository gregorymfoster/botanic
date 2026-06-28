import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Opens the system dialer for a phone number. Shared by the Grounding screen's support/emergency
/// buttons and the live Today "Support" action. No-ops on a number that can't form a `tel://` URL.
enum PhoneDialer {
    /// Whether `number` contains enough to dial — used to decide between dialing and a fallback.
    static func canDial(_ number: String) -> Bool {
        !sanitize(number).isEmpty
    }

    static func dial(_ number: String) {
        let digits = sanitize(number)
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private static func sanitize(_ number: String) -> String {
        number.filter { $0.isNumber || $0 == "+" }
    }
}
