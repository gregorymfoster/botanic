import Foundation

/// Derives the live serif words shown alongside a check-in's three sliders (valence, intensity,
/// body load) and the single orb word that blends all three. Pure and deterministic so the check-in
/// UI can preview words on every drag without touching a model.
public enum CheckInWordEngine {
    /// The unpleasant→pleasant word for a 0…1 valence value.
    public static func valenceWord(_ v: Double) -> String {
        let value = clamp(v)
        switch value {
        case ..<0.25: return "rough"
        case ..<0.5: return "uneasy"
        case ..<0.75: return "pleasant"
        default: return "lovely"
        }
    }

    /// The intensity word for a 0…1 intensity value.
    public static func intensityWord(_ v: Double) -> String {
        let value = clamp(v)
        switch value {
        case ..<0.20: return "still"
        case ..<0.45: return "gentle"
        case ..<0.75: return "steady"
        default: return "strong"
        }
    }

    /// The body-load word for a 0…1 body load value.
    public static func bodyLoadWord(_ v: Double) -> String {
        let value = clamp(v)
        switch value {
        case ..<0.25: return "light"
        case ..<0.5: return "soft"
        case ..<0.75: return "present"
        default: return "heavy"
        }
    }

    /// The orb's single blended word, chosen primarily by valence with intensity and body load
    /// steering between calmer and more energized words at similar valence. A readable decision
    /// table rather than a scoring formula, so the mapping stays easy to reason about and retune.
    public static func orbWord(valence: Double, intensity: Double, bodyLoad: Double) -> FeelingWord {
        let v = clamp(valence)
        let i = clamp(intensity)
        let b = clamp(bodyLoad)
        let energized = i >= 0.5 || b >= 0.5

        switch v {
        case ..<0.20:
            // Low valence: energized reads as restless agitation, calm reads as plain tiredness.
            return energized ? .restless : .tired
        case ..<0.40:
            return energized ? .restless : .tender
        case ..<0.60:
            // Mid valence: body load pulls toward tenderness, intensity alone pulls toward clarity.
            if b >= 0.5 { return .tender }
            return i >= 0.5 ? .clear : .grounded
        case ..<0.75:
            if energized { return .warm }
            return .calm
        case ..<0.9:
            if energized { return .grateful }
            return .settled
        default:
            return energized ? .luminous : .settled
        }
    }

    /// Sorts `tags` by descending usage count (from `usageCounts`, defaulting to 0), keeping ties in
    /// their original relative order (a stable sort) so the canonical chip ordering only changes once
    /// the user actually establishes a usage pattern.
    public static func orderedTags(_ tags: [String], usageCounts: [String: Int]) -> [String] {
        tags.enumerated()
            .sorted { lhs, rhs in
                let lc = usageCounts[lhs.element] ?? 0
                let rc = usageCounts[rhs.element] ?? 0
                if lc != rc { return lc > rc }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}
