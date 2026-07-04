import Foundation

/// Who authored an experience's title/subtitle — an on-device draft the app generated, or text the
/// user typed/edited themselves. Drives whether the app treats the copy as safe to silently
/// regenerate versus something to preserve.
public enum TitleSource: String, Codable, Sendable, Equatable {
    case ai
    case user
}
