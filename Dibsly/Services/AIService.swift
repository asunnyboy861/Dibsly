import Foundation
import Observation
import StoreKit
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ListingDraft {
    var title: String
    var details: String
    var category: ItemCategory
    var estValueCents: Int
    var engine: String
}

struct AIModeration {
    var verdict: ModerationVerdict
    var reasons: [String]
    var cleanTitle: String?
    var cleanDetails: String?
    var category: ItemCategory?
    var estValueCents: Int?
    var engine: String
}

struct WantedDraft {
    var title: String
    var keywords: [String]
    var category: ItemCategory
    var engine: String
}

struct AIMessage {
    let role: String
    let content: String
}

protocol AIProvider {
    var id: String { get }
    var displayName: String { get }
    func complete(system: String, messages: [AIMessage], json: Bool) async throws -> String
}

enum AIProviderError: LocalizedError {
    case invalidEndpoint
    case missingKey
    case httpStatus(Int)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "The endpoint is not a valid URL."
        case .missingKey: return "This engine needs an API key."
        case .httpStatus(let code): return "The AI service returned HTTP \(code)."
        case .malformedResponse: return "The AI service returned an unexpected response."
        }
    }
}

struct OpenAICompatibleProvider: AIProvider {
    let id: String
    let displayName: String
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let extraHeaders: [String: String]

    init(id: String, displayName: String, baseURL: URL, apiKey: String, model: String, extraHeaders: [String: String] = [:]) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.extraHeaders = extraHeaders
    }

    private var endpoint: URL {
        if baseURL.path.contains("chat/completions") { return baseURL }
        var url = baseURL
        if !url.path.hasSuffix("/") {
            url.appendPathComponent("chat/completions")
        }
        return url
    }

    func complete(system: String, messages: [AIMessage], json: Bool) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingKey }
        var payloadMessages: [[String: Any]] = [["role": "system", "content": system]]
        payloadMessages.append(contentsOf: messages.map { ["role": $0.role, "content": $0.content] })
        var body: [String: Any] = [
            "model": model,
            "messages": payloadMessages,
            "temperature": 0.3,
            "max_tokens": 1200
        ]
        if json { body["response_format"] = ["type": "json_object"] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIProviderError.httpStatus(http.statusCode) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            throw AIProviderError.malformedResponse
        }
        if let content = message["content"] as? String { return content }
        if let parts = message["content"] as? [[String: Any]] {
            let merged = parts.compactMap { $0["text"] as? String }.joined()
            if !merged.isEmpty { return merged }
        }
        throw AIProviderError.malformedResponse
    }
}

struct AnthropicProvider: AIProvider {
    let id: String = "claude"
    let displayName: String = "Claude"
    private let baseURL: URL
    private let apiKey: String
    private let model: String

    init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    func complete(system: String, messages: [AIMessage], json: Bool) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingKey }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1200,
            "system": system,
            "messages": messages.map { ["role": $0.role == "assistant" ? "assistant" : "user", "content": $0.content] }
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIProviderError.httpStatus(http.statusCode) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = object["content"] as? [[String: Any]] else {
            throw AIProviderError.malformedResponse
        }
        let merged = content.compactMap { $0["text"] as? String }.joined()
        guard !merged.isEmpty else { throw AIProviderError.malformedResponse }
        return merged
    }
}

struct GLMProxyProvider: AIProvider {
    let id: String = "dibsly-cloud"
    let displayName: String = "Dibsly cloud AI"

    private let appId = "dibsly"
    private let primaryURL: URL
    private let fallbackURL = URL(string: "https://cramjam-proxy.iocompile67692.workers.dev")!
    private let model: String
    private let devKey: String

    init(endpoint: URL, model: String, devKey: String) {
        self.primaryURL = endpoint
        self.model = model
        self.devKey = devKey
    }

    private var userId: String {
        if let saved = KeychainHelper.readString(service: AIConfiguration.service, account: "proxy.user.id"),
           !saved.isEmpty {
            return saved
        }
        let generated = UUID().uuidString
        KeychainHelper.saveString(generated, service: AIConfiguration.service, account: "proxy.user.id")
        return generated
    }

    private func entitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            let jws = result.jwsRepresentation
            if !jws.isEmpty { return jws }
        }
        return nil
    }

    func complete(system: String, messages: [AIMessage], json: Bool) async throws -> String {
        var payloadMessages: [[String: Any]] = [["role": "system", "content": system]]
        payloadMessages.append(contentsOf: messages.map { ["role": $0.role, "content": $0.content] })

        var payload: [String: Any] = [
            "model": model,
            "messages": payloadMessages,
            "thinking": ["level": "low"],
            "max_tokens": 8192
        ]
        if json {
            payload["response_format"] = ["type": "json_object"]
        }

        var body: [String: Any] = [
            "appId": appId,
            "userId": userId,
            "payload": payload
        ]

        if let jws = await entitlementJWS() {
            body["appTransaction"] = jws
        } else {
            body["devKey"] = devKey
        }

        do {
            return try await send(url: primaryURL, body: body)
        } catch AIProviderError.httpStatus(let code) where code >= 500 {
            return try await send(url: fallbackURL, body: body)
        } catch AIProviderError.malformedResponse {
            return try await send(url: fallbackURL, body: body)
        }
    }

    private func send(url: URL, body: [String: Any]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedResponse }
        switch http.statusCode {
        case 200:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  !content.isEmpty else {
                throw AIProviderError.malformedResponse
            }
            return content
        default:
            throw AIProviderError.httpStatus(http.statusCode)
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct AppleIntelligenceProvider: AIProvider {
    let id: String = "apple"
    let displayName: String = "Apple Intelligence"

    func complete(system: String, messages: [AIMessage], json: Bool) async throws -> String {
        let session = LanguageModelSession(instructions: system)
        let prompt = messages.map { $0.content }.joined(separator: "\n")
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif

@Observable
@MainActor
final class AIService {
    var appleAvailable: Bool
    var byoConfigured: Bool
    var proxyConfigured: Bool
    var lastEngineUsed: String = "On-device rules"
    var lastError: String?

    @ObservationIgnored private let proxyProfiles: [ProxyProfile]

    init() {
        let profiles = AIConfiguration.bundledProfiles()
        proxyProfiles = profiles
        proxyConfigured = !profiles.isEmpty
        appleAvailable = AppleIntelligence.isAvailable
        byoConfigured = AIConfiguration.byoKey() != nil
    }

    var engineSummary: String {
        if byoConfigured { return "Your own key" }
        if appleAvailable { return "Apple Intelligence" }
        if proxyConfigured { return "Dibsly cloud AI" }
        return "On-device rules"
    }

    func refreshState() {
        appleAvailable = AppleIntelligence.isAvailable
        byoConfigured = AIConfiguration.byoKey() != nil
        proxyConfigured = !proxyProfiles.isEmpty
    }

    func draftListing(rawText: String, categoryHint: ItemCategory?, cloudAllowed: Bool) async -> ListingDraft {
        let fallback = Self.heuristicDraft(rawText: rawText, hint: categoryHint)
        guard let provider = selectProvider(cloudAllowed: cloudAllowed) else {
            lastEngineUsed = fallback.engine
            return fallback
        }
        let system = "You help neighbors give things away for free in the United States. Answer with a single JSON object and no prose."
        let prompt = """
        Draft a free-stuff listing from this note: "\(rawText)"
        Return JSON with keys title, details, category, est_value_usd.
        title: friendly, at most 60 characters, no price.
        details: 1-2 sentences, mention condition if present.
        category: one of furniture, electronics, baby, clothing, kitchen, books, tools, garden, other.
        est_value_usd: a realistic used resale value as a number.
        """
        do {
            let raw = try await provider.complete(system: system, messages: [AIMessage(role: "user", content: prompt)], json: true)
            guard let data = Self.jsonPayload(from: raw),
                  let dto = try? JSONDecoder().decode(DraftDTO.self, from: data) else {
                throw AIProviderError.malformedResponse
            }
            let draft = ListingDraft(
                title: Self.sanitizedTitle(dto.title, fallback: fallback.title),
                details: (dto.details?.isEmpty == false ? dto.details! : fallback.details),
                category: Self.category(from: dto.category) ?? fallback.category,
                estValueCents: max(0, Int((dto.est_value_usd ?? Double(fallback.estValueCents / 100)) * 100)),
                engine: provider.displayName
            )
            lastEngineUsed = provider.displayName
            return draft
        } catch {
            lastError = error.localizedDescription
            lastEngineUsed = fallback.engine
            return fallback
        }
    }

    func estimateValue(title: String, details: String, category: ItemCategory, cloudAllowed: Bool) async -> Int {
        let fallback = Self.heuristicValue(title: title, details: details, category: category)
        guard let provider = selectProvider(cloudAllowed: cloudAllowed) else { return fallback }
        let prompt = """
        Estimate the realistic used resale value in US dollars for this free item.
        Title: \(title)
        Details: \(details)
        Category: \(category.title)
        Return JSON: {"est_value_usd": number}
        """
        do {
            let raw = try await provider.complete(system: "You are a careful secondhand market appraiser. Answer with JSON only.", messages: [AIMessage(role: "user", content: prompt)], json: true)
            guard let data = Self.jsonPayload(from: raw),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let value = object["est_value_usd"] as? Double else {
                return fallback
            }
            let cents = max(0, Int(value * 100))
            return cents > 0 ? cents : fallback
        } catch {
            lastError = error.localizedDescription
            return fallback
        }
    }

    func moderate(title: String, details: String, category: ItemCategory, cloudAllowed: Bool) async -> AIModeration? {
        guard let provider = selectProvider(cloudAllowed: cloudAllowed) else { return nil }
        let system = "You are the trust and safety reviewer for a free-stuff neighborhood app. Answer with JSON only."
        let prompt = """
        Review this listing.
        Title: \(title)
        Details: \(details)
        Category: \(category.title)
        Return JSON with keys verdict (PASS, REVIEW or BLOCK), reasons (array of short strings), category, est_value_usd, clean_title, clean_details.
        BLOCK for weapons, drugs, alcohol, food, live animals, recalled or unsafe goods, stolen goods, adult products.
        REVIEW for commercial resale, deposits, shipping, payment app requests, missing details.
        PASS for genuine free household items.
        """
        do {
            let raw = try await provider.complete(system: system, messages: [AIMessage(role: "user", content: prompt)], json: true)
            guard let data = Self.jsonPayload(from: raw),
                  let dto = try? JSONDecoder().decode(ModerationDTO.self, from: data) else {
                throw AIProviderError.malformedResponse
            }
            let verdict = ModerationVerdict(rawValue: (dto.verdict ?? "").uppercased()) ?? .review
            lastEngineUsed = provider.displayName
            return AIModeration(
                verdict: verdict,
                reasons: dto.reasons ?? [],
                cleanTitle: dto.clean_title,
                cleanDetails: dto.clean_details,
                category: Self.category(from: dto.category),
                estValueCents: dto.est_value_usd.map { max(0, Int($0 * 100)) },
                engine: provider.displayName
            )
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func structureWanted(text: String, cloudAllowed: Bool) async -> WantedDraft {
        let fallback = Self.heuristicWanted(text: text)
        guard let provider = selectProvider(cloudAllowed: cloudAllowed) else { return fallback }
        let prompt = """
        Convert this request into a wanted post for a free-stuff neighborhood app.
        Request: "\(text)"
        Return JSON with keys title, keywords (array of 3-6 short search terms), category.
        category: furniture, electronics, baby, clothing, kitchen, books, tools, garden, other.
        """
        do {
            let raw = try await provider.complete(system: "You structure neighborhood requests. Answer with JSON only.", messages: [AIMessage(role: "user", content: prompt)], json: true)
            guard let data = Self.jsonPayload(from: raw),
                  let dto = try? JSONDecoder().decode(WantedDTO.self, from: data) else {
                return fallback
            }
            let keywords = (dto.keywords ?? []).map { $0.lowercased() }.filter { !$0.isEmpty }
            return WantedDraft(
                title: Self.sanitizedTitle(dto.title, fallback: fallback.title),
                keywords: keywords.isEmpty ? fallback.keywords : keywords,
                category: Self.category(from: dto.category) ?? fallback.category,
                engine: provider.displayName
            )
        } catch {
            lastError = error.localizedDescription
            return fallback
        }
    }

    func testConnection() async -> (success: Bool, message: String) {
        guard let provider = makeBYOProvider() else {
            return (false, "Add your own API key first.")
        }
        do {
            let reply = try await provider.complete(system: "Reply with the single word OK.", messages: [AIMessage(role: "user", content: "OK check")], json: false)
            return (true, "\(provider.displayName) replied: \(reply.prefix(40))")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func selectProvider(cloudAllowed: Bool) -> AIProvider? {
        if let byo = makeBYOProvider() { return byo }
        if appleAvailable, let apple = makeAppleProvider() { return apple }
        if cloudAllowed, let proxy = makeProxyProvider() { return proxy }
        return nil
    }

    private func makeBYOProvider() -> AIProvider? {
        guard let key = AIConfiguration.byoKey(), !key.isEmpty else { return nil }
        guard let url = URL(string: AIConfiguration.byoBase()) else { return nil }
        let providerID = AIConfiguration.byoProviderID()
        let model = AIConfiguration.byoModel()
        if providerID == "claude" {
            return AnthropicProvider(baseURL: url, apiKey: key, model: model)
        }
        return OpenAICompatibleProvider(
            id: providerID,
            displayName: BYOProviderOption.option(for: providerID).title,
            baseURL: url,
            apiKey: key,
            model: model
        )
    }

    private func makeProxyProvider() -> AIProvider? {
        guard let profile = proxyProfiles.first else { return nil }
        return GLMProxyProvider(endpoint: profile.endpoint, model: profile.model, devKey: profile.key)
    }

    private func makeAppleProvider() -> AIProvider? {
        guard #available(iOS 26.0, *) else { return nil }
        #if canImport(FoundationModels)
        return AppleIntelligenceProvider()
        #else
        return nil
        #endif
    }
}

private struct DraftDTO: Decodable {
    let title: String?
    let details: String?
    let category: String?
    let est_value_usd: Double?
}

private struct ModerationDTO: Decodable {
    let verdict: String?
    let reasons: [String]?
    let category: String?
    let est_value_usd: Double?
    let clean_title: String?
    let clean_details: String?
}

private struct WantedDTO: Decodable {
    let title: String?
    let keywords: [String]?
    let category: String?
}

extension AIService {
    static func jsonPayload(from raw: String) -> Data? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else { return nil }
        let slice = raw[start...end]
        return String(slice).data(using: .utf8)
    }

    static func category(from raw: String?) -> ItemCategory? {
        guard let raw else { return nil }
        let lower = raw.lowercased()
        return ItemCategory.allCases.first { $0.rawValue == lower }
    }

    static func sanitizedTitle(_ candidate: String?, fallback: String) -> String {
        let raw = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = raw.isEmpty ? fallback : raw
        return String(title.prefix(60))
    }

    static func heuristicCategory(for text: String) -> ItemCategory {
        let lower = text.lowercased()
        let rules: [(ItemCategory, [String])] = [
            (.furniture, ["sofa", "couch", "chair", "table", "desk", "dresser", "bed", "shelf", "bookcase", "mattress", "lamp"]),
            (.electronics, ["tv", "monitor", "laptop", "computer", "phone", "speaker", "console", "playstation", "xbox", "printer", "camera", "airpods"]),
            (.baby, ["stroller", "crib", "baby", "toddler", "high chair", "diaper", "bassinet", "car seat"]),
            (.clothing, ["shirt", "jacket", "coat", "dress", "shoes", "boots", "jeans", "sweater"]),
            (.kitchen, ["pan", "pot", "dish", "plate", "mug", "blender", "microwave", "toaster", "air fryer"]),
            (.books, ["book", "books", "novel", "textbook", "comics"]),
            (.tools, ["drill", "saw", "hammer", "wrench", "ladder", "toolbox", "lawn mower"]),
            (.garden, ["plant", "pot", "soil", "garden", "planter", "mulch"])
        ]
        for (category, keywords) in rules where keywords.contains(where: { lower.contains($0) }) {
            return category
        }
        return .other
    }

    static func heuristicValue(title: String, details: String, category: ItemCategory) -> Int {
        let base: [ItemCategory: Int] = [
            .furniture: 120,
            .electronics: 90,
            .baby: 65,
            .clothing: 28,
            .kitchen: 35,
            .books: 15,
            .tools: 50,
            .garden: 22,
            .other: 30
        ]
        var dollars = base[category] ?? 30
        let lower = (title + " " + details).lowercased()
        let premium = ["leather", "wood", "wooden", "oak", "new", "brand new", "unused", "solid", "vintage", "mid century", "apple", "sony", "nintendo", "dyson", "vitamix", "ikea"]
        if premium.contains(where: { lower.contains($0) }) { dollars = Int(Double(dollars) * 1.45) }
        let damaged = ["broken", "cracked", "scratch", "scratched", "needs work", "missing", "old", "worn", "stained", "parts"]
        if damaged.contains(where: { lower.contains($0) }) { dollars = Int(Double(dollars) * 0.55) }
        return max(0, dollars * 100)
    }

    static func heuristicDraft(rawText: String, hint: ItemCategory?) -> ListingDraft {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = hint ?? heuristicCategory(for: text.isEmpty ? (hint?.title ?? "") : text)
        let title: String
        if text.isEmpty {
            title = "Free \(category.title.lowercased())"
        } else {
            let words = text.split(separator: " ").prefix(9).joined(separator: " ")
            title = String(words.prefix(60))
        }
        let details = text.isEmpty ? "Free to a good home. First dibs wins." : text
        let cents = heuristicValue(title: title, details: details, category: category)
        return ListingDraft(
            title: title.isEmpty ? "Free item" : title,
            details: details,
            category: category,
            estValueCents: cents,
            engine: "On-device rules"
        )
    }

    static func heuristicWanted(text: String) -> WantedDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = heuristicCategory(for: trimmed)
        let words = trimmed.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let stopWords: Set<String> = ["need", "needed", "want", "wanted", "looking", "for", "a", "an", "the", "and", "my", "we", "i", "free", "please", "some", "any"]
        let keywords = Array(Set(words.map(String.init).filter { $0.count > 2 && !stopWords.contains($0) })).sorted().prefix(6)
        return WantedDraft(
            title: trimmed.isEmpty ? "Wanted: free item" : String("Wanted: \(trimmed)".prefix(60)),
            keywords: Array(keywords),
            category: category,
            engine: "On-device rules"
        )
    }
}
