import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: String = UUID().uuidString
    var title: String = ""
    var details: String = ""
    var categoryRaw: String = ItemCategory.other.rawValue
    var estValueCents: Int = 0
    var photoFileNames: [String] = []
    var statusRaw: String = ItemStatus.pendingReview.rawValue
    var geohash5: String = ""
    var city: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var giverID: String = ""
    var giverName: String = ""
    var giverTrustAtPost: Int = 5
    var dibsByID: String?
    var dibsByName: String?
    var dibsExpiresAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var moderationVerdictRaw: String = ModerationVerdict.review.rawValue
    var isRemote: Bool = false
    var handedOverAt: Date?
    var receivedAt: Date?
    var archivedReason: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        details: String,
        category: ItemCategory,
        estValueCents: Int,
        photoFileNames: [String],
        status: ItemStatus = .live,
        geohash5: String,
        city: String,
        latitude: Double,
        longitude: Double,
        giverID: String,
        giverName: String,
        giverTrustAtPost: Int,
        moderationVerdict: ModerationVerdict = .pass,
        isRemote: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.categoryRaw = category.rawValue
        self.estValueCents = estValueCents
        self.photoFileNames = photoFileNames
        self.statusRaw = status.rawValue
        self.geohash5 = geohash5
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.giverID = giverID
        self.giverName = giverName
        self.giverTrustAtPost = giverTrustAtPost
        self.createdAt = Date()
        self.updatedAt = Date()
        self.moderationVerdictRaw = moderationVerdict.rawValue
        self.isRemote = isRemote
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .pendingReview }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var verdict: ModerationVerdict {
        get { ModerationVerdict(rawValue: moderationVerdictRaw) ?? .review }
        set { moderationVerdictRaw = newValue.rawValue }
    }

    var valueDollars: Int { estValueCents / 100 }

    var isHighValue: Bool { estValueCents >= 15000 }

    var isClaimable: Bool { status == .live && createdAt.timeIntervalSinceNow > -604800 }

    var dibsRemaining: TimeInterval {
        guard let expires = dibsExpiresAt else { return 0 }
        return max(0, expires.timeIntervalSinceNow)
    }

    var isDibsExpired: Bool {
        guard let expires = dibsExpiresAt else { return false }
        return expires < Date()
    }

    var fuzzyCoordinate: (latitude: Double, longitude: Double) {
        guard latitude != 0 || longitude != 0 else { return (0, 0) }
        let seed = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let latOffset = Double((seed % 601) - 300) / 111000.0
        let lonOffset = Double((seed % 457) - 228) / 85000.0
        return (latitude + latOffset, longitude + lonOffset)
    }

    var categorySymbol: String { category.symbol }
}

@Model
final class Claim {
    @Attribute(.unique) var id: String = UUID().uuidString
    var itemID: String = ""
    var takerID: String = ""
    var takerName: String = ""
    var resultRaw: String = ClaimResult.lost.rawValue
    var clientUUID: String = ""
    var createdAt: Date = Date()

    init(itemID: String, takerID: String, takerName: String, result: ClaimResult, clientUUID: String) {
        self.id = UUID().uuidString
        self.itemID = itemID
        self.takerID = takerID
        self.takerName = takerName
        self.resultRaw = result.rawValue
        self.clientUUID = clientUUID
        self.createdAt = Date()
    }

    var result: ClaimResult {
        get { ClaimResult(rawValue: resultRaw) ?? .lost }
        set { resultRaw = newValue.rawValue }
    }
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String = UUID().uuidString
    var itemID: String = ""
    var senderID: String = ""
    var senderName: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    var isSystem: Bool = false

    init(itemID: String, senderID: String, senderName: String, text: String, isSystem: Bool = false) {
        self.id = UUID().uuidString
        self.itemID = itemID
        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.createdAt = Date()
        self.isSystem = isSystem
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: String = UUID().uuidString
    var handle: String = ""
    var displayName: String = ""
    var trustScore: Int = 5
    var city: String = ""
    var isPro: Bool = false
    var credits: Int = 0
    var createdAt: Date = Date()
    var phoneVerified: Bool = false

    init(handle: String, displayName: String, city: String) {
        self.id = UUID().uuidString
        self.handle = handle
        self.displayName = displayName
        self.city = city
        self.createdAt = Date()
        self.trustScore = 5
    }

    var badge: TrustBadge { TrustBadge.from(score: trustScore) }
}

@Model
final class TrustEvent {
    @Attribute(.unique) var id: String = UUID().uuidString
    var userID: String = ""
    var delta: Int = 0
    var reasonRaw: String = TrustReason.signup.rawValue
    var note: String = ""
    var createdAt: Date = Date()

    init(userID: String, reason: TrustReason, note: String = "") {
        self.id = UUID().uuidString
        self.userID = userID
        self.delta = reason.delta
        self.reasonRaw = reason.rawValue
        self.note = note
        self.createdAt = Date()
    }

    var reason: TrustReason {
        TrustReason(rawValue: reasonRaw) ?? .signup
    }
}

@Model
final class WantedPost {
    @Attribute(.unique) var id: String = UUID().uuidString
    var title: String = ""
    var rawText: String = ""
    var keywords: [String] = []
    var categoryRaw: String = ItemCategory.other.rawValue
    var city: String = ""
    var createdAt: Date = Date()
    var matchedItemID: String?

    init(title: String, rawText: String, keywords: [String], category: ItemCategory, city: String) {
        self.id = UUID().uuidString
        self.title = title
        self.rawText = rawText
        self.keywords = keywords
        self.categoryRaw = category.rawValue
        self.city = city
        self.createdAt = Date()
    }

    var category: ItemCategory {
        ItemCategory(rawValue: categoryRaw) ?? .other
    }
}

@Model
final class ModerationLog {
    @Attribute(.unique) var id: String = UUID().uuidString
    var itemID: String = ""
    var verdictRaw: String = ModerationVerdict.review.rawValue
    var reasons: [String] = []
    var model: String = ""
    var createdAt: Date = Date()

    init(itemID: String, verdict: ModerationVerdict, reasons: [String], model: String) {
        self.id = UUID().uuidString
        self.itemID = itemID
        self.verdictRaw = verdict.rawValue
        self.reasons = reasons
        self.model = model
        self.createdAt = Date()
    }
}
