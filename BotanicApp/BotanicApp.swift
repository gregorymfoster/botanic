import Sentry
import SwiftData
import SwiftUI

@main
struct BotanicApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://7f8808e4abcd4b953d52ce0b38a031b7@o4511673711198208.ingest.us.sentry.io/4511678116659200"
            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
            options.tracesSampleRate = 0.2
        }
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
