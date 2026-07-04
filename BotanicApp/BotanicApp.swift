import SwiftData
import SwiftUI

@main
struct BotanicApp: App {
    init() {
        AppFonts.registerAll()
        Dusk.applyControlAppearance()
        BackupManager.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Dusk.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            Experience.self, SupplementEntry.self, CheckIn.self, JournalEntry.self, SupplementLibraryItem.self
        ])
    }
}
