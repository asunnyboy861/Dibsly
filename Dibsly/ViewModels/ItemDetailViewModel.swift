import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ItemDetailViewModel {
    var isClaiming: Bool = false
    var showCelebration: Bool = false
    var claimError: String?
    var requiresPro: Bool = false
    var claims: [Claim] = []
    var similarItems: [Item] = []
    var showSafeExchange: Bool = false
    var statusMessage: String?
    var isReporting: Bool = false

    static let safetyChecklist: [String] = [
        "Meet in a public place like a police station or a busy store",
        "Bring a friend for the first pickup",
        "Meet in daylight when possible",
        "Tell someone where you are going",
        "Do not go inside a stranger's home",
        "Keep your phone charged and visible"
    ]

    func load(item: Item, env: AppEnvironment) {
        expireIfNeeded(item: item, env: env)
        loadClaims(item: item, env: env)
        loadSimilar(item: item, env: env)
    }

    func expireIfNeeded(item: Item, env: AppEnvironment) {
        guard item.status == .dibbed, item.isDibsExpired else { return }
        item.status = .live
        item.dibsByID = nil
        item.dibsByName = nil
        item.dibsExpiresAt = nil
        try? env.context.save()
        statusMessage = "That dibs expired and the item went back to the neighborhood."
    }

    func loadClaims(item: Item, env: AppEnvironment) {
        let itemID = item.id
        let descriptor = FetchDescriptor<Claim>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = (try? env.context.fetch(descriptor)) ?? []
        claims = all.filter { $0.itemID == itemID && $0.result == .win }
    }

    func loadSimilar(item: Item, env: AppEnvironment, limit: Int = 4) {
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = (try? env.context.fetch(descriptor)) ?? []
        similarItems = Array(all
            .filter { $0.id != item.id && $0.status == .live }
            .sorted { left, right in
                if left.category == item.category && right.category != item.category { return true }
                if right.category == item.category && left.category != item.category { return false }
                return left.createdAt > right.createdAt
            }
            .prefix(limit))
    }

    func claim(item: Item, env: AppEnvironment) async -> Bool {
        guard !isClaiming else { return false }
        guard let profile = env.profile else {
            claimError = "Your neighbor profile is still loading."
            return false
        }
        guard item.status == .live else {
            claimError = "Someone else already called dibs. Try a similar one."
            loadSimilar(item: item, env: env)
            return false
        }
        guard item.giverID != profile.id else {
            claimError = "This is your own listing."
            return false
        }

        if item.isHighValue && item.createdAt.timeIntervalSinceNow > -60 && !PurchaseManager.shared.isPro {
            requiresPro = true
            claimError = "High-value items get a 60-second Pro head start."
            return false
        }

        isClaiming = true
        defer { isClaiming = false }

        let clientUUID = UUID().uuidString

        if item.isRemote {
            let result = await env.cloud.tryClaim(
                itemID: item.id,
                takerID: profile.id,
                takerName: profile.displayName
            )
            if result == .lost || result == .expired {
                recordClaim(item: item, profile: profile, result: .lost, clientUUID: clientUUID, env: env)
                claimError = "Already taken. Here are other free items nearby."
                loadSimilar(item: item, env: env)
                return false
            }
        }

        item.status = .dibbed
        item.dibsByID = profile.id
        item.dibsByName = profile.displayName
        item.dibsExpiresAt = Date().addingTimeInterval(600)
        recordClaim(item: item, profile: profile, result: .win, clientUUID: clientUUID, env: env)
        ensureOpeningMessages(item: item, profile: profile, env: env)
        env.notifications.scheduleDibsExpiry(
            itemID: item.id,
            title: item.title,
            expiresAt: item.dibsExpiresAt ?? Date().addingTimeInterval(600)
        )
        try? env.context.save()
        showCelebration = true
        claimError = nil
        env.requestNotifications()
        return true
    }

    private func recordClaim(item: Item, profile: UserProfile, result: ClaimResult, clientUUID: String, env: AppEnvironment) {
        let descriptor = FetchDescriptor<Claim>()
        let existing = (try? env.context.fetch(descriptor)) ?? []
        if existing.contains(where: { $0.clientUUID == clientUUID }) { return }
        let claim = Claim(
            itemID: item.id,
            takerID: profile.id,
            takerName: profile.displayName,
            result: result,
            clientUUID: clientUUID
        )
        env.context.insert(claim)
        try? env.context.save()
    }

    private func ensureOpeningMessages(item: Item, profile: UserProfile, env: AppEnvironment) {
        let itemID = item.id
        let descriptor = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let all = (try? env.context.fetch(descriptor)) ?? []
        guard !all.contains(where: { $0.itemID == itemID }) else { return }
        env.context.insert(ChatMessage(
            itemID: itemID,
            senderID: "system",
            senderName: "Dibsly",
            text: "You called dibs on \(item.title). Message the giver and agree on a public meetup spot within 10 minutes.",
            isSystem: true
        ))
        env.context.insert(ChatMessage(
            itemID: itemID,
            senderID: "system",
            senderName: "Safety tips",
            text: "Meet in a public place, bring a friend, meet in daylight, and tell someone where you are going.",
            isSystem: true
        ))
        try? env.context.save()
    }

    func accept(claimant: Claim, item: Item, env: AppEnvironment) {
        item.dibsByID = claimant.takerID
        item.dibsByName = claimant.takerName
        item.status = .dibbed
        item.dibsExpiresAt = Date().addingTimeInterval(600)
        for other in claims where other.id != claimant.id {
            other.result = .lost
        }
        try? env.context.save()
        statusMessage = "\(claimant.takerName) is picking it up."
    }

    func markGiven(item: Item, env: AppEnvironment) {
        guard let profile = env.profile, item.giverID == profile.id else { return }
        item.status = .given
        item.handedOverAt = Date()
        env.trust.apply(.giveDone, to: profile, context: env.context, note: item.title)
        try? env.context.save()
        Task { await env.cloud.markRemoteGiven(itemID: item.id) }
        statusMessage = "Marked as given. Waiting for the neighbor to confirm."
    }

    func confirmReceived(item: Item, env: AppEnvironment) {
        guard let profile = env.profile, item.dibsByID == profile.id else { return }
        guard item.status == .given else {
            statusMessage = "The giver needs to mark it given first."
            return
        }
        item.status = .done
        item.receivedAt = Date()
        env.trust.apply(.claimDone, to: profile, context: env.context, note: item.title)
        try? env.context.save()
        Task { await env.cloud.markRemoteDone(itemID: item.id) }
        statusMessage = "Confirmed. Your saved total just went up."
    }

    func archive(item: Item, env: AppEnvironment) {
        item.status = .archived
        item.archivedReason = "Removed by giver"
        try? env.context.save()
    }

    func report(item: Item, reason: String, env: AppEnvironment) {
        isReporting = true
        defer { isReporting = false }
        env.context.insert(ModerationLog(
            itemID: item.id,
            verdict: .review,
            reasons: ["Neighbor report: \(reason)"],
            model: "community"
        ))
        item.status = .humanQueue
        try? env.context.save()
        env.context.insert(ChatMessage(
            itemID: item.id,
            senderID: "system",
            senderName: "Dibsly Trust",
            text: "Thanks. This listing is now in review and will not show in the feed.",
            isSystem: true
        ))
        try? env.context.save()
        statusMessage = "Report received. Trust and safety will review it."
    }

    func markNoShow(item: Item, claim: Claim, env: AppEnvironment) {
        claim.result = .expired
        item.status = .live
        item.dibsByID = nil
        item.dibsByName = nil
        item.dibsExpiresAt = nil
        try? env.context.save()
        statusMessage = "The dibs was released for a no-show."
    }
}
