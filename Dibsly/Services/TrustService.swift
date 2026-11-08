import Foundation
import SwiftData

@MainActor
final class TrustService {
    func apply(_ reason: TrustReason, to profile: UserProfile, context: ModelContext, note: String = "") {
        profile.trustScore = max(0, profile.trustScore + reason.delta)
        let event = TrustEvent(userID: profile.id, reason: reason, note: note)
        context.insert(event)
        try? context.save()
    }

    func events(for profile: UserProfile, context: ModelContext) -> [TrustEvent] {
        let userID = profile.id
        let descriptor = FetchDescriptor<TrustEvent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.userID == userID }
    }
}
