import Foundation

/// The single-word summary of how an experience feels, chosen on a check-in and used as the
/// experience's headline feeling in history and insights. User-authored vocabulary — descriptive,
/// never prescriptive.
public enum FeelingWord: String, CaseIterable, Sendable, Codable, Identifiable {
    case settled = "Settled"
    case grounded = "Grounded"
    case calm = "Calm"
    case warm = "Warm"
    case clear = "Clear"
    case luminous = "Luminous"
    case tender = "Tender"
    case grateful = "Grateful"
    case tired = "Tired"
    case restless = "Restless"

    public var id: String { rawValue }

    /// The 0…1 position of this feeling on the unpleasant→pleasant axis. Used to seed a check-in's
    /// valence slider and to compute the felt-trend in `InsightsEngine`.
    public var valence: Double {
        switch self {
        case .luminous: return 0.95
        case .grateful: return 0.9
        case .settled: return 0.82
        case .calm: return 0.8
        case .grounded: return 0.75
        case .warm: return 0.72
        case .clear: return 0.68
        case .tender: return 0.5
        case .tired: return 0.4
        case .restless: return 0.3
        }
    }
}

/// The "What's present?" chips offered on a check-in. Free, additive — the user can pick any.
public enum PresenceTag {
    public static let all = [
        "Grounded", "Calm", "Warm", "Clear", "Tired", "Restless",
        "Open", "Soft", "Alert", "Heavy", "Light", "Tearful"
    ]
}
