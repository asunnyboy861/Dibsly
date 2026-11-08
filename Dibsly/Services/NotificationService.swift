import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    var isAuthorized: Bool = false
    var permissionDenied: Bool = false

    func requestAuthorization() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permissionDenied = !isAuthorized
        } catch {
            isAuthorized = false
            permissionDenied = true
        }
    }

    func scheduleDibsExpiry(itemID: String, title: String, expiresAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Your dibs is about to release"
        content.body = "\(title) goes back to the neighborhood in 2 minutes unless you message the giver."
        content.sound = .default
        let interval = max(120, expiresAt.timeIntervalSinceNow - 120)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dibs-expiry-\(itemID)",
            content: content,
            trigger: trigger
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    func scheduleWantedMatch(itemID: String, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Your wanted post has a match"
        content.body = "\(title) was just posted nearby. Dibs it before someone else does."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "wanted-match-\(itemID)",
            content: content,
            trigger: trigger
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    func notifyHighValueItem(title: String, valueDollars: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Hot free item nearby"
        content.body = "\(title) is worth about $\(valueDollars). First dibs wins."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "hot-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    func cancel(itemID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "dibs-expiry-\(itemID)",
            "wanted-match-\(itemID)"
        ])
    }
}
