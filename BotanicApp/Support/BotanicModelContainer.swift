import SwiftData

/// The app-owned persistent container. Live Activity intents execute in the main app process, so
/// sharing this construction keeps their writes on the same store and away from the widget
/// extension's read/render process.
enum BotanicModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for:
                Experience.self,
                SupplementEntry.self,
                CheckIn.self,
                JournalEntry.self,
                SupplementLibraryItem.self
            )
        } catch {
            fatalError("Botanic could not open its model container: \(error.localizedDescription)")
        }
    }()
}
