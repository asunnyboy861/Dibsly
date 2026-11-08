import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class PostItemViewModel {
    var photos: [UIImage] = []
    var rawNote: String = ""
    var title: String = ""
    var details: String = ""
    var category: ItemCategory = .other
    var estValueCents: Int = 0
    var isDrafting: Bool = false
    var isSubmitting: Bool = false
    var draftEngine: String = ""
    var blockMessage: String?
    var blockReasons: [String] = []
    var errorMessage: String?
    var hasDrafted: Bool = false

    var canPost: Bool {
        photos.count > 0 && !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSubmitting
    }

    func addPhoto(_ image: UIImage) {
        guard photos.count < 3 else { return }
        photos.append(image)
    }

    func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
    }

    func draft(with ai: AIService, cloudAllowed: Bool) async {
        isDrafting = true
        defer { isDrafting = false }
        let draft = await ai.draftListing(rawText: rawNote, categoryHint: nil, cloudAllowed: cloudAllowed)
        title = draft.title
        details = draft.details
        category = draft.category
        estValueCents = draft.estValueCents
        draftEngine = draft.engine
        hasDrafted = true
    }

    func submit(env: AppEnvironment) async -> Item? {
        guard canPost else { return nil }
        guard let profile = env.profile else {
            errorMessage = "Neighbor profile is still loading."
            return nil
        }

        let existingDescriptor = FetchDescriptor<Item>()
        let existingItems = (try? env.context.fetch(existingDescriptor)) ?? []
        let postedToday = existingItems.filter {
            $0.giverID == profile.id && Calendar.current.isDateInToday($0.createdAt)
        }.count
        if postedToday >= 1 && !PurchaseManager.shared.isPro {
            errorMessage = "Free neighbors can post one item per day. Pro makes posting unlimited."
            return nil
        }

        isSubmitting = true
        defer { isSubmitting = false }

        var savedNames: [String] = []
        for photo in photos {
            if let name = ImageStore.shared.save(photo) {
                savedNames.append(name)
            }
        }
        guard !savedNames.isEmpty else {
            errorMessage = "Photos could not be saved. Try again."
            return nil
        }

        let cloudAllowed = PurchaseManager.shared.isPro || PurchaseManager.shared.hasCredits || env.ai.byoConfigured
        let outcome = await env.moderation.evaluate(
            title: title,
            details: details,
            category: category,
            estValueCents: estValueCents,
            ai: env.ai,
            cloudAllowed: cloudAllowed
        )

        if outcome.verdict == .block {
            for name in savedNames { ImageStore.shared.delete(name) }
            blockMessage = "This post cannot go live"
            blockReasons = outcome.reasons
            return nil
        }

        let coordinate = env.location.coordinate
        let geohash = Geohash.encode(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let city = env.location.city.isEmpty ? "Your city" : env.location.city
        let status: ItemStatus = outcome.verdict == .review ? .humanQueue : .live

        let item = Item(
            title: outcome.title,
            details: outcome.details,
            category: outcome.category,
            estValueCents: outcome.estValueCents,
            photoFileNames: savedNames,
            status: status,
            geohash5: geohash,
            city: city,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            giverID: profile.id,
            giverName: profile.displayName,
            giverTrustAtPost: profile.trustScore,
            moderationVerdict: outcome.verdict
        )
        env.context.insert(item)
        env.context.insert(ModerationLog(
            itemID: item.id,
            verdict: outcome.verdict,
            reasons: outcome.reasons,
            model: outcome.engine
        ))
        try? env.context.save()

        if status == .live {
            Task {
                await env.cloud.publish(item: item, imageName: savedNames.first)
            }
            if item.isHighValue {
                env.notifications.notifyHighValueItem(title: item.title, valueDollars: item.valueDollars)
            }
            matchWantedPosts(with: item, profile: profile, env: env)
        }

        return item
    }

    private func matchWantedPosts(with item: Item, profile: UserProfile, env: AppEnvironment) {
        let descriptor = FetchDescriptor<WantedPost>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let posts = (try? env.context.fetch(descriptor)) ?? []
        for post in posts where post.matchedItemID == nil {
            let haystack = item.title.lowercased() + " " + item.details.lowercased()
            let keywordHit = post.keywords.contains { haystack.contains($0) }
            if keywordHit || post.category == item.category {
                post.matchedItemID = item.id
                env.notifications.scheduleWantedMatch(itemID: item.id, title: item.title)
            }
        }
        try? env.context.save()
    }

    func reset() {
        photos = []
        rawNote = ""
        title = ""
        details = ""
        category = .other
        estValueCents = 0
        blockMessage = nil
        blockReasons = []
        errorMessage = nil
        hasDrafted = false
        draftEngine = ""
    }
}
