import Foundation
import SwiftData

/// A remembered supplement, used to speed up future logging with the last amount and intention
/// used. Upserted whenever a supplement is logged via `ExperienceStore.addSupplement`.
@Model
final class SupplementLibraryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var lastAmount: String?
    var lastIntention: String?
    var useCount: Int
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        lastAmount: String? = nil,
        lastIntention: String? = nil,
        useCount: Int = 1,
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.lastAmount = lastAmount
        self.lastIntention = lastIntention
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}
