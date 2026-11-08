import Combine
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class HaulsViewModel {
    func claimedItems(profile: UserProfile, items: [Item]) -> [Item] {
        items.filter { item in
            item.dibsByID == profile.id &&
            (item.status == .dibbed || item.status == .meeting || item.status == .given || item.status == .done)
        }
    }

    func givenItems(profile: UserProfile, items: [Item]) -> [Item] {
        items.filter { item in
            item.giverID == profile.id &&
            (item.status == .dibbed || item.status == .meeting || item.status == .given || item.status == .done)
        }
    }

    func savedCents(_ items: [Item]) -> Int {
        items.filter { $0.status == .done }.reduce(0) { $0 + $1.estValueCents }
    }

    func doneClaims(profile: UserProfile, items: [Item]) -> [Item] {
        items.filter { $0.dibsByID == profile.id && $0.status == .done }
    }

    func activeCount(profile: UserProfile, items: [Item]) -> Int {
        items.filter { ($0.dibsByID == profile.id || $0.giverID == profile.id) && ($0.status == .dibbed || $0.status == .given) }.count
    }
}

@Observable
@MainActor
final class WantedViewModel {
    var rawText: String = ""
    var isMatching: Bool = false
    var matchMessage: String?
    var lastCreatedPost: WantedPost?

    func create(env: AppEnvironment) async -> WantedPost? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            matchMessage = "Describe what you are looking for."
            return nil
        }
        isMatching = true
        defer { isMatching = false }

        let cloudAllowed = PurchaseManager.shared.isPro || PurchaseManager.shared.hasCredits || env.ai.byoConfigured
        let draft = await env.ai.structureWanted(text: trimmed, cloudAllowed: cloudAllowed)
        let post = WantedPost(
            title: draft.title,
            rawText: trimmed,
            keywords: draft.keywords,
            category: draft.category,
            city: env.location.city.isEmpty ? "Your city" : env.location.city
        )
        env.context.insert(post)

        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = (try? env.context.fetch(descriptor)) ?? []
        let best = all
            .filter { $0.status == .live }
            .map { ($0, score(item: $0, post: post)) }
            .filter { $0.1 >= 2 }
            .sorted { $0.1 > $1.1 }
            .first
        if let match = best {
            post.matchedItemID = match.0.id
            env.notifications.scheduleWantedMatch(itemID: match.0.id, title: match.0.title)
            matchMessage = "Match found: \(match.0.title)"
        } else {
            matchMessage = "Posted. We will alert you when something matches."
        }
        try? env.context.save()
        lastCreatedPost = post
        rawText = ""
        return post
    }

    func score(item: Item, post: WantedPost) -> Int {
        let haystack = (item.title + " " + item.details).lowercased()
        var score = 0
        if item.category == post.category { score += 2 }
        for keyword in post.keywords where haystack.contains(keyword) { score += 1 }
        if item.estValueCents > 0 { score += 1 }
        return score
    }

    func matches(for post: WantedPost, items: [Item]) -> [Item] {
        items.filter { item in
            item.status == .live && score(item: item, post: post) >= 2
        }
    }
}

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var draft: String = ""
    var scamWarning: String?
    var isSyncing: Bool = false
    var errorMessage: String?

    private let scamTerms: [String] = [
        "venmo", "zelle", "cash app", "cashapp", "paypal", "deposit", "shipping", "ship only",
        "wire", "crypto", "bitcoin", "gift card", "pay first", "hold fee"
    ]

    func load(item: Item, env: AppEnvironment) {
        loadLocal(item: item, env: env)
        Task { await sync(item: item, env: env) }
    }

    func loadLocal(item: Item, env: AppEnvironment) {
        let itemID = item.id
        let descriptor = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let all = (try? env.context.fetch(descriptor)) ?? []
        messages = all.filter { $0.itemID == itemID }
    }

    func sync(item: Item, env: AppEnvironment) async {
        guard item.isRemote else { return }
        isSyncing = true
        defer { isSyncing = false }
        let remote = await env.cloud.fetchMessages(itemID: item.id)
        let descriptor = FetchDescriptor<ChatMessage>()
        let existing = (try? env.context.fetch(descriptor)) ?? []
        let knownIDs = Set(existing.map { $0.id })
        var inserted = false
        for message in remote where !knownIDs.contains(message.id) {
            let local = ChatMessage(
                itemID: message.itemID,
                senderID: message.senderID,
                senderName: message.senderName,
                text: message.text
            )
            local.id = message.id
            local.createdAt = message.createdAt
            env.context.insert(local)
            inserted = true
        }
        if inserted {
            try? env.context.save()
            loadLocal(item: item, env: env)
        }
    }

    func send(item: Item, env: AppEnvironment) async {
        guard let profile = env.profile else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let message = ChatMessage(
            itemID: item.id,
            senderID: profile.id,
            senderName: profile.displayName,
            text: text
        )
        env.context.insert(message)
        try? env.context.save()
        draft = ""
        let warning = scamCheck(text)
        scamWarning = warning
        loadLocal(item: item, env: env)
        if item.isRemote {
            await env.cloud.sendMessage(
                itemID: item.id,
                senderID: profile.id,
                senderName: profile.displayName,
                text: text
            )
        }
    }

    func scamCheck(_ text: String) -> String? {
        let lower = text.lowercased()
        let hits = scamTerms.filter { lower.contains($0) }
        guard !hits.isEmpty else { return nil }
        return "Careful: real neighbors never ask for deposits, shipping fees, or payment apps for free items."
    }
}

@Observable
@MainActor
final class ProfileViewModel {
    var events: [TrustEvent] = []
    var displayNameDraft: String = ""
    var savedMessage: String?

    func load(profile: UserProfile, env: AppEnvironment) {
        events = env.trust.events(for: profile, context: env.context)
        displayNameDraft = profile.displayName
    }

    func saveName(profile: UserProfile, env: AppEnvironment) {
        let name = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        profile.displayName = name
        try? env.context.save()
        savedMessage = "Saved."
    }
}

@Observable
@MainActor
final class PaywallViewModel {
    var selectedID: String = PurchaseManager.yearlyID
    var isPurchasing: Bool = false
    var message: String?

    func purchaseSelected() async -> Bool {
        let manager = PurchaseManager.shared
        guard let product = manager.product(for: selectedID) else {
            message = "This product is not available yet. Try again in a moment."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        let success = await manager.purchase(product)
        if success {
            message = "Pro unlocked. Check the quick-grab window."
        } else if let error = manager.loadError {
            message = error
        }
        return success
    }

    func purchaseCredits(productID: String) async -> Bool {
        let manager = PurchaseManager.shared
        guard let product = manager.product(for: productID) else {
            message = "Credits are not available yet. Try again in a moment."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        let success = await manager.purchase(product)
        if success { message = "Credits added." }
        return success
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isPro: Bool = false
    @Published var credits: Int = 0

    private let purchaseManager = PurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        purchaseManager.$isPro
            .receive(on: RunLoop.main)
            .assign(to: &$isPro)
        purchaseManager.$credits
            .receive(on: RunLoop.main)
            .assign(to: &$credits)
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    func restore() async {
        await purchaseManager.restorePurchases()
    }

    func price(for id: String) -> String {
        purchaseManager.displayPrice(for: id)
    }

    func reloadProducts() async {
        await purchaseManager.loadProducts()
        await purchaseManager.refreshEntitlements()
    }
}
