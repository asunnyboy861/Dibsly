import SwiftUI

enum ItemStatus: String, Codable, CaseIterable {
    case pendingReview = "PENDING_REVIEW"
    case humanQueue = "HUMAN_QUEUE"
    case live = "LIVE"
    case dibbed = "DIBBED"
    case meeting = "MEETING"
    case given = "GIVEN"
    case done = "DONE"
    case archived = "ARCHIVED"
    case rejected = "REJECTED"
}

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case furniture
    case electronics
    case baby
    case clothing
    case kitchen
    case books
    case tools
    case garden
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .furniture: return "Furniture"
        case .electronics: return "Electronics"
        case .baby: return "Baby & Kids"
        case .clothing: return "Clothing"
        case .kitchen: return "Kitchen"
        case .books: return "Books"
        case .tools: return "Tools"
        case .garden: return "Garden"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .furniture: return "chair.lounge.fill"
        case .electronics: return "tv.fill"
        case .baby: return "teddybear.fill"
        case .clothing: return "tshirt.fill"
        case .kitchen: return "frying.pan.fill"
        case .books: return "books.vertical.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .garden: return "leaf.fill"
        case .other: return "shippingbox.fill"
        }
    }
}

enum ModerationVerdict: String, Codable {
    case pass = "PASS"
    case review = "REVIEW"
    case block = "BLOCK"
}

enum ClaimResult: String, Codable {
    case win = "WIN"
    case lost = "LOST"
    case expired = "EXPIRED"
}

enum TrustReason: String, Codable, CaseIterable {
    case signup = "SIGNUP"
    case giveDone = "GIVE_DONE"
    case claimDone = "CLAIM_DONE"
    case onTime = "ON_TIME"
    case noShow = "NO_SHOW"
    case scam = "SCAM"
    case report = "REPORT"

    var delta: Int {
        switch self {
        case .signup: return 5
        case .giveDone: return 3
        case .claimDone: return 2
        case .onTime: return 1
        case .noShow: return -5
        case .scam: return -20
        case .report: return -10
        }
    }

    var label: String {
        switch self {
        case .signup: return "Joined the neighborhood"
        case .giveDone: return "Gave an item away"
        case .claimDone: return "Received an item"
        case .onTime: return "On-time handoff"
        case .noShow: return "No-show"
        case .scam: return "Scam confirmed"
        case .report: return "Report upheld"
        }
    }

    var isPositive: Bool { delta > 0 }
}

enum TrustBadge: String, CaseIterable {
    case newbie
    case neighbor
    case trusted
    case legend

    static func from(score: Int) -> TrustBadge {
        if score >= 100 { return .legend }
        if score >= 50 { return .trusted }
        if score >= 10 { return .neighbor }
        return .newbie
    }

    var title: String {
        switch self {
        case .newbie: return "Newbie"
        case .neighbor: return "Neighbor"
        case .trusted: return "Trusted"
        case .legend: return "Legend"
        }
    }

    var symbol: String {
        switch self {
        case .newbie: return "leaf"
        case .neighbor: return "house.fill"
        case .trusted: return "checkmark.seal.fill"
        case .legend: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .newbie: return Color(white: 0.55)
        case .neighbor: return DesignSystem.green
        case .trusted: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .legend: return Color(red: 0.95, green: 0.72, blue: 0.18)
        }
    }
}

enum FeedMode: String, CaseIterable {
    case map
    case list
}

enum AITaskKind: String {
    case drafting
    case valuation
    case moderation
    case wanted
    case chatGuard

    var title: String {
        switch self {
        case .drafting: return "Draft a listing"
        case .valuation: return "Estimate value"
        case .moderation: return "Moderation scan"
        case .wanted: return "Structure a wanted post"
        case .chatGuard: return "Chat safety check"
        }
    }
}
