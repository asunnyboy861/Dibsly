import Foundation

struct FeedbackRequest: Codable {
    let name: String
    let email: String
    let subject: String
    let message: String
    let app_name: String
}

enum ContactSupportError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Something went wrong. Please try again."
        }
    }
}

final class ContactSupportService {
    static let shared = ContactSupportService()

    private let endpoint = URL(string: "https://msg.calcs.top/api/feedback")!

    func submit(name: String, email: String, subject: String, message: String, appName: String) async throws {
        let payload = FeedbackRequest(name: name, email: email, subject: subject, message: message, app_name: appName)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ContactSupportError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = object["error"] as? String {
                throw ContactSupportError.server(message)
            }
            throw ContactSupportError.server("Feedback could not be sent right now.")
        }
    }
}
