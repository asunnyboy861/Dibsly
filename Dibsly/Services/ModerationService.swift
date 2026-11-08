import Foundation
import SwiftData

struct ModerationOutcome {
    var verdict: ModerationVerdict
    var reasons: [String]
    var title: String
    var details: String
    var category: ItemCategory
    var estValueCents: Int
    var engine: String
}

@MainActor
final class ModerationService {
    private let bannedTerms: [String] = [
        "gun", "firearm", "rifle", "handgun", "ammo", "ammunition", "taser", "silencer",
        "cocaine", "heroin", "meth", "fentanyl", "marijuana", "cannabis", "weed", "vape", "nicotine",
        "beer", "wine", "liquor", "alcohol", "prescription", "oxycodone", "adderall",
        "expired food", "raw meat", "breast milk", "live animal", "puppy", "kitten",
        "recalled", "car seat expired", "adult toy", "fireworks"
    ]

    private let reviewTerms: [String] = [
        "venmo", "zelle", "cash app", "cashapp", "paypal", "deposit", "shipping", "ship only",
        "dm me", "wholesale", "bulk", "for sale", "selling", "price", "per item", "invoice",
        "brand new in box", "reseller", "flip"
    ]

    func evaluate(
        title: String,
        details: String,
        category: ItemCategory,
        estValueCents: Int,
        ai: AIService,
        cloudAllowed: Bool
    ) async -> ModerationOutcome {
        let combined = (title + " " + details).lowercased()
        var verdict: ModerationVerdict = .pass
        var reasons: [String] = []
        var engine = "On-device rules"

        let bannedHits = bannedTerms.filter { combined.contains($0) }
        if !bannedHits.isEmpty {
            verdict = .block
            reasons.append(contentsOf: bannedHits.map { "Restricted item: \($0)" })
        }

        let reviewHits = reviewTerms.filter { combined.contains($0) }
        if !reviewHits.isEmpty {
            if verdict == .pass { verdict = .review }
            reasons.append(contentsOf: reviewHits.prefix(3).map { "Possible commercial or payment request: \($0)" })
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            if verdict == .pass { verdict = .review }
            reasons.append("Title is too short to review")
        }
        if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if verdict == .pass { verdict = .review }
            reasons.append("Add a short description so neighbors trust the post")
        }

        var finalTitle = title
        var finalDetails = details
        var finalCategory = category
        var finalValue = estValueCents

        if let aiResult = await ai.moderate(title: title, details: details, category: category, cloudAllowed: cloudAllowed) {
            engine = aiResult.engine
            reasons.append(contentsOf: aiResult.reasons)
            if aiResult.verdict == .block { verdict = .block }
            if aiResult.verdict == .review && verdict == .pass { verdict = .review }
            if let cleanTitle = aiResult.cleanTitle, !cleanTitle.isEmpty { finalTitle = cleanTitle }
            if let cleanDetails = aiResult.cleanDetails, !cleanDetails.isEmpty { finalDetails = cleanDetails }
            if let newCategory = aiResult.category { finalCategory = newCategory }
            if let newValue = aiResult.estValueCents { finalValue = newValue }
        }

        if verdict == .pass && reasons.isEmpty {
            reasons = ["Looks like a genuine free listing"]
        }

        let uniqueReasons = Array(Set(reasons)).sorted()

        return ModerationOutcome(
            verdict: verdict,
            reasons: uniqueReasons,
            title: finalTitle,
            details: finalDetails,
            category: finalCategory,
            estValueCents: finalValue,
            engine: engine
        )
    }
}
