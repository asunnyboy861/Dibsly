import Observation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {
    let container: ModelContainer
    let location = LocationService()
    let cloud = CloudKitService()
    let ai = AIService()
    let moderation = ModerationService()
    let trust = TrustService()
    let notifications = NotificationService()

    var profile: UserProfile?
    var hasOnboarded: Bool = false
    var cloudAvailable: Bool = false
    var cloudStatus: String = "Local only"

    init(inMemory: Bool = false) {
        let schema = Schema([
            Item.self,
            Claim.self,
            ChatMessage.self,
            UserProfile.self,
            TrustEvent.self,
            WantedPost.self,
            ModerationLog.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        if let created = try? ModelContainer(for: schema, configurations: [configuration]) {
            container = created
        } else {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: [memory])
        }
        hasOnboarded = UserDefaults.standard.bool(forKey: "dibsly.onboarded")
        if ProcessInfo.processInfo.arguments.contains("-uitest-onboarded") {
            hasOnboarded = true
        }
    }

    var context: ModelContext { container.mainContext }

    var displayName: String {
        profile?.displayName ?? "Neighbor"
    }

    var badge: TrustBadge {
        profile?.badge ?? .newbie
    }

    var isPro: Bool {
        PurchaseManager.shared.isPro
    }

    var credits: Int {
        PurchaseManager.shared.credits
    }

    func bootstrap() {
        bootstrapProfile()
        refreshCloud()
    }

    func bootstrapProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            profile = existing
            return
        }
        let profile = UserProfile(
            handle: "@neighbor",
            displayName: "Neighbor",
            city: location.city.isEmpty ? "Your city" : location.city
        )
        context.insert(profile)
        context.insert(TrustEvent(userID: profile.id, reason: .signup))
        try? context.save()
        self.profile = profile
    }

    func updateCity(_ city: String) {
        guard let profile, !city.isEmpty, profile.city != city else { return }
        profile.city = city
        try? context.save()
    }

    func markOnboarded() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "dibsly.onboarded")
    }

    func refreshCloud() {
        Task {
            await cloud.refreshAvailability()
            cloudAvailable = cloud.isAvailable
            cloudStatus = cloud.lastSyncDescription
        }
    }

    func syncPurchaseState() {
        guard let profile else { return }
        profile.isPro = PurchaseManager.shared.isPro
        profile.credits = PurchaseManager.shared.credits
        try? context.save()
    }

    func requestNotifications() {
        Task { await notifications.requestAuthorization() }
    }
}
