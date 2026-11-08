import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct BYOProviderOption: Identifiable, Hashable {
    let id: String
    let title: String
    let defaultBase: String
    let defaultModel: String
    let symbol: String

    static let all: [BYOProviderOption] = [
        BYOProviderOption(id: "glm", title: "GLM", defaultBase: "https://api.z.ai/api/paas/v4", defaultModel: "glm-4.5v", symbol: "sparkles"),
        BYOProviderOption(id: "openai", title: "OpenAI compatible", defaultBase: "https://api.openai.com/v1", defaultModel: "gpt-4o-mini", symbol: "circle.hexagongrid.fill"),
        BYOProviderOption(id: "deepseek", title: "DeepSeek", defaultBase: "https://api.deepseek.com/v1", defaultModel: "deepseek-chat", symbol: "drop.fill"),
        BYOProviderOption(id: "gemini", title: "Gemini (compatible)", defaultBase: "https://generativelanguage.googleapis.com/v1beta/openai", defaultModel: "gemini-2.5-flash", symbol: "sun.max.fill"),
        BYOProviderOption(id: "claude", title: "Claude", defaultBase: "https://api.anthropic.com/v1", defaultModel: "claude-sonnet-4-20250514", symbol: "text.bubble.fill"),
        BYOProviderOption(id: "custom", title: "Custom endpoint", defaultBase: "https://your-proxy.example.com/v1", defaultModel: "your-model", symbol: "link")
    ]

    static func option(for id: String) -> BYOProviderOption {
        all.first { $0.id == id } ?? all[0]
    }
}

struct ProxyProfile {
    let key: String
    let endpoint: URL
    let model: String
}

enum AIConfiguration {
    static let service = "com.zzoutuo.Dibsly.ai"
    private static let keyAccount = "byo.key"
    private static let providerAccount = "byo.provider"
    private static let baseAccount = "byo.base"
    private static let modelAccount = "byo.model"

    static func byoKey() -> String? {
        let value = KeychainHelper.readString(service: service, account: keyAccount) ?? ""
        return value.isEmpty ? nil : value
    }

    static func byoProviderID() -> String {
        UserDefaults.standard.string(forKey: providerAccount) ?? "glm"
    }

    static func byoBase() -> String {
        if let saved = UserDefaults.standard.string(forKey: baseAccount), !saved.isEmpty { return saved }
        return BYOProviderOption.option(for: byoProviderID()).defaultBase
    }

    static func byoModel() -> String {
        if let saved = UserDefaults.standard.string(forKey: modelAccount), !saved.isEmpty { return saved }
        return BYOProviderOption.option(for: byoProviderID()).defaultModel
    }

    static func saveBYO(providerID: String, base: String, model: String, key: String) {
        UserDefaults.standard.set(providerID, forKey: providerAccount)
        UserDefaults.standard.set(base, forKey: baseAccount)
        UserDefaults.standard.set(model, forKey: modelAccount)
        if key.isEmpty {
            KeychainHelper.delete(service: service, account: keyAccount)
        } else {
            KeychainHelper.saveString(key, service: service, account: keyAccount)
        }
    }

    static func clearBYO() {
        UserDefaults.standard.removeObject(forKey: providerAccount)
        UserDefaults.standard.removeObject(forKey: baseAccount)
        UserDefaults.standard.removeObject(forKey: modelAccount)
        KeychainHelper.delete(service: service, account: keyAccount)
    }

    static func bundledProfiles() -> [ProxyProfile] {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let parts = trimmed.split(separator: "|").map { String($0) }
            guard parts.count >= 3, let endpoint = URL(string: parts[1]) else { return nil }
            return ProxyProfile(key: parts[0], endpoint: endpoint, model: parts[2])
        }
    }
}

enum AppleIntelligence {
    static var isAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #else
        return false
        #endif
    }
}
