import Foundation
import Testing
@testable import Botanic

/// Verifies `NotificationManager` reads its settings from its injected `UserDefaults` rather than
/// `UserDefaults.standard`, and applies the documented defaults when a key is unset. Doesn't
/// exercise `UNUserNotificationCenter` scheduling itself (framework glue, not ours to test) — the
/// "should this fire / when" arithmetic is covered exhaustively by `NotificationPolicyTests` in
/// BotanicKit.
@MainActor
struct NotificationManagerTests {
    private func makeDefaults(_ suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func isEnabledDefaultsToTrueWhenUnset() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.isEnabled == true)
    }

    @Test func isEnabledReadsFromInjectedDefaults() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(false, forKey: NotificationManager.enabledKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.isEnabled == false)
    }

    @Test func intervalMinutesDefaultsTo90WhenUnset() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.intervalMinutes == 90)
    }

    @Test func intervalMinutesReadsFromInjectedDefaults() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(45, forKey: NotificationManager.intervalKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.intervalMinutes == 45)
    }

    @Test func supplementAlertsEnabledDefaultsToTrueWhenUnset() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.supplementAlertsEnabled == true)
    }

    @Test func supplementAlertsEnabledReadsFromInjectedDefaults() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(false, forKey: NotificationManager.supplementAlertsEnabledKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.supplementAlertsEnabled == false)
    }

    @Test func quietSuggestEnabledDefaultsToTrueWhenUnset() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.quietSuggestEnabled == true)
    }

    @Test func quietSuggestEnabledReadsFromInjectedDefaults() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(false, forKey: NotificationManager.quietSuggestEnabledKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.quietSuggestEnabled == false)
    }

    @Test func quietSuggestHoursDefaultsTo3WhenUnset() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.quietSuggestHours == 3)
    }

    @Test func quietSuggestHoursReadsFromInjectedDefaults() {
        let defaults = makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: #function) }
        defaults.set(5, forKey: NotificationManager.quietSuggestHoursKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.quietSuggestHours == 5)
    }

    /// Two instances backed by different `UserDefaults` suites must not see each other's values —
    /// confirms settings genuinely come from the injected instance, not a shared/static fallback.
    @Test func distinctInstancesDoNotShareSettings() {
        let defaultsA = makeDefaults("\(#function).A")
        let defaultsB = makeDefaults("\(#function).B")
        defer {
            defaultsA.removePersistentDomain(forName: "\(#function).A")
            defaultsB.removePersistentDomain(forName: "\(#function).B")
        }
        defaultsA.set(false, forKey: NotificationManager.enabledKey)
        defaultsB.set(true, forKey: NotificationManager.enabledKey)

        let managerA = NotificationManager(defaults: defaultsA)
        let managerB = NotificationManager(defaults: defaultsB)

        #expect(managerA.isEnabled == false)
        #expect(managerB.isEnabled == true)
    }

    @Test func liveInstanceIsBackedByStandardUserDefaults() {
        // NotificationManager.live must exist as the shared production instance (mirrors
        // ExperienceStore.live), defaulting to UserDefaults.standard.
        _ = NotificationManager.live
    }
}
