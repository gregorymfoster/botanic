import Foundation

/// A small rotating set of gentle, open reflective prompts for the freeform journal composer.
/// Descriptive and inviting — they ask, they don't advise.
public enum JournalPrompt {
    public static let all = [
        "What does your body want you to know right now?",
        "What's softening, and what's still holding on?",
        "If this evening had a texture, what would it be?",
        "What are you grateful for in this exact moment?",
        "What would you tell yourself an hour ago?",
        "Where do you feel the most ease right now?",
        "What word keeps surfacing tonight?",
        "What does quiet feel like in your body?"
    ]

    /// A deterministic prompt for a given step, so "New prompt" cycles predictably without RNG.
    public static func at(_ index: Int) -> String {
        guard !all.isEmpty else { return "" }
        let i = ((index % all.count) + all.count) % all.count
        return all[i]
    }
}
