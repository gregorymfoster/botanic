import Foundation
import Testing
@testable import Botanic

@Suite("TagUsageStore")
struct TagUsageStoreTests {
    @Test func incrementAndCountsRoundTripThroughInjectedDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TagUsageStore(defaults: defaults)

        #expect(store.counts().isEmpty)

        store.increment(["calm", "grateful"])
        store.increment(["calm"])

        #expect(store.counts() == ["calm": 2, "grateful": 1])
    }

    @Test func incrementWithEmptyTagsIsNoOp() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TagUsageStore(defaults: defaults)

        store.increment([])

        #expect(store.counts().isEmpty)
    }

    @Test func distinctInstancesDoNotShareCounts() {
        let defaultsA = UserDefaults(suiteName: #function + "A")!
        let defaultsB = UserDefaults(suiteName: #function + "B")!
        defaultsA.removePersistentDomain(forName: #function + "A")
        defaultsB.removePersistentDomain(forName: #function + "B")

        let storeA = TagUsageStore(defaults: defaultsA)
        let storeB = TagUsageStore(defaults: defaultsB)

        storeA.increment(["focused"])

        #expect(storeA.counts() == ["focused": 1])
        #expect(storeB.counts().isEmpty)
    }
}
