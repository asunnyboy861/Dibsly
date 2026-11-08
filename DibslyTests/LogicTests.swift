import SwiftData
import UIKit
import XCTest
@testable import Dibsly

@MainActor
final class LogicTests: XCTestCase {
    private var env: AppEnvironment!

    override func setUpWithError() throws {
        continueAfterFailure = false
        env = AppEnvironment(inMemory: true)
        env.bootstrapProfile()
    }

    func testProfileBootstrap() {
        XCTAssertNotNil(env.profile)
        XCTAssertEqual(env.profile?.displayName, "Neighbor")
        XCTAssertEqual(env.profile?.trustScore, 5)
        XCTAssertEqual(env.badge, .newbie)
    }

    func testBundledCloudProfilePresent() {
        let profiles = AIConfiguration.bundledProfiles()
        XCTAssertFalse(profiles.isEmpty, "GLMProxySecret.txt should ship in Debug builds")
        XCTAssertEqual(profiles.first?.model, "glm-5.3-flash")
    }

    func testGeohashPrecision() {
        let hash = Geohash.encode(latitude: 40.7128, longitude: -74.0060, precision: 5)
        XCTAssertEqual(hash.count, 5)
        XCTAssertEqual(Geohash.cellSizeMeters(precision: 5), 4900)
    }

    func testTrustBadges() {
        XCTAssertEqual(TrustBadge.from(score: 5), .newbie)
        XCTAssertEqual(TrustBadge.from(score: 10), .neighbor)
        XCTAssertEqual(TrustBadge.from(score: 50), .trusted)
        XCTAssertEqual(TrustBadge.from(score: 100), .legend)
    }

    func testAIDraftFallsBackOnDevice() async {
        let draft = await env.ai.draftListing(rawText: "gray fabric sofa", categoryHint: nil, cloudAllowed: false)
        XCTAssertTrue(draft.title.lowercased().contains("sofa"))
        XCTAssertEqual(draft.category, .furniture)
        XCTAssertGreaterThan(draft.estValueCents, 0)
    }

    func testPostCreatesLiveItem() async throws {
        let vm = PostItemViewModel()
        vm.photos = [makeImage()]
        vm.rawNote = "gray fabric sofa with two cushions"
        await vm.draft(with: env.ai, cloudAllowed: false)
        XCTAssertTrue(vm.title.lowercased().contains("sofa"))

        let item = await vm.submit(env: env)
        let created = try XCTUnwrap(item)
        XCTAssertEqual(created.status, .live)
        XCTAssertFalse(created.photoFileNames.isEmpty)
        XCTAssertEqual(created.giverID, env.profile?.id)

        let items = try env.context.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        let logs = try env.context.fetch(FetchDescriptor<ModerationLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.verdictRaw, ModerationVerdict.pass.rawValue)
    }

    func testBannedItemIsBlocked() async throws {
        let vm = PostItemViewModel()
        vm.photos = [makeImage()]
        vm.title = "Hunting rifle for free"
        vm.details = "Comes with ammunition and a case"
        vm.category = .tools

        let item = await vm.submit(env: env)
        XCTAssertNil(item)
        XCTAssertNotNil(vm.blockMessage)
        XCTAssertFalse(vm.blockReasons.isEmpty)

        let items = try env.context.fetch(FetchDescriptor<Item>())
        XCTAssertTrue(items.isEmpty)
    }

    func testPaymentRequestGoesToReview() async throws {
        let vm = PostItemViewModel()
        vm.photos = [makeImage()]
        vm.title = "Free sectional sofa"
        vm.details = "venmo deposit required, shipping only"
        vm.category = .furniture

        let item = await vm.submit(env: env)
        let created = try XCTUnwrap(item)
        XCTAssertEqual(created.status, .humanQueue)
    }

    func testClaimFlowAndDoubleConfirmation() async throws {
        let giver = try XCTUnwrap(env.profile)
        let item = makeItem(giver: giver, title: "Wooden dining chair")
        env.context.insert(item)
        try env.context.save()

        let taker = UserProfile(handle: "@taker", displayName: "Taker", city: "New York")
        env.context.insert(taker)
        try env.context.save()
        env.profile = taker

        let vm = ItemDetailViewModel()
        let claimed = await vm.claim(item: item, env: env)
        XCTAssertTrue(claimed)
        XCTAssertEqual(item.status, .dibbed)
        XCTAssertEqual(item.dibsByID, taker.id)
        XCTAssertTrue(vm.showCelebration)

        let claims = try env.context.fetch(FetchDescriptor<Claim>())
        XCTAssertEqual(claims.filter { $0.result == .win }.count, 1)

        let messages = try env.context.fetch(FetchDescriptor<ChatMessage>())
        XCTAssertFalse(messages.filter { $0.itemID == item.id }.isEmpty)

        vm.confirmReceived(item: item, env: env)
        XCTAssertEqual(item.status, .dibbed, "Taker must not close before the giver marks given")

        env.profile = giver
        let giverBefore = giver.trustScore
        vm.markGiven(item: item, env: env)
        XCTAssertEqual(item.status, .given)
        XCTAssertEqual(giver.trustScore, giverBefore + TrustReason.giveDone.delta)

        env.profile = taker
        let takerBefore = taker.trustScore
        vm.confirmReceived(item: item, env: env)
        XCTAssertEqual(item.status, .done)
        XCTAssertEqual(taker.trustScore, takerBefore + TrustReason.claimDone.delta)

        let events = try env.context.fetch(FetchDescriptor<TrustEvent>())
        XCTAssertGreaterThanOrEqual(events.count, 3)
    }

    func testOwnItemCannotBeClaimed() async throws {
        let giver = try XCTUnwrap(env.profile)
        let item = makeItem(giver: giver, title: "Free bookshelf")
        env.context.insert(item)
        try env.context.save()

        let vm = ItemDetailViewModel()
        let claimed = await vm.claim(item: item, env: env)
        XCTAssertFalse(claimed)
        XCTAssertEqual(item.status, .live)
        XCTAssertNotNil(vm.claimError)
    }

    func testWantedMatchesExistingListing() async throws {
        let giver = try XCTUnwrap(env.profile)
        let item = makeItem(giver: giver, title: "Wooden dining chair", category: .furniture)
        env.context.insert(item)
        try env.context.save()

        let vm = WantedViewModel()
        vm.rawText = "wooden chair for my dining table"
        let post = await vm.create(env: env)

        let created = try XCTUnwrap(post)
        XCTAssertEqual(created.matchedItemID, item.id)
        XCTAssertFalse(created.keywords.isEmpty)
    }

    func testModerationBlockAndReviewRules() async {
        let service = ModerationService()
        let blocked = await service.evaluate(
            title: "Rifle and ammo",
            details: "Free to take",
            category: .tools,
            estValueCents: 0,
            ai: env.ai,
            cloudAllowed: false
        )
        XCTAssertEqual(blocked.verdict, .block)

        let review = await service.evaluate(
            title: "Free sofa",
            details: "venmo deposit required",
            category: .furniture,
            estValueCents: 0,
            ai: env.ai,
            cloudAllowed: false
        )
        XCTAssertEqual(review.verdict, .review)

        let pass = await service.evaluate(
            title: "Free wooden chair",
            details: "Solid oak, pickup on Saturday in the driveway",
            category: .furniture,
            estValueCents: 12000,
            ai: env.ai,
            cloudAllowed: false
        )
        XCTAssertEqual(pass.verdict, .pass)
    }

    func testLowballEstimateAndDistanceHelpers() throws {
        let cents = AIService.heuristicValue(title: "Broken old sofa", details: "needs work", category: .furniture)
        XCTAssertLessThan(cents, 12000)

        let premium = AIService.heuristicValue(title: "Solid oak dining table", details: "great condition", category: .furniture)
        XCTAssertGreaterThan(premium, AIService.heuristicValue(title: "Old table", details: "worn", category: .furniture))
    }

    private func makeItem(
        giver: UserProfile,
        title: String,
        category: ItemCategory = .furniture
    ) -> Item {
        Item(
            title: title,
            details: "Free to a good home",
            category: category,
            estValueCents: 8000,
            photoFileNames: [],
            status: .live,
            geohash5: "dr5ru",
            city: "New York",
            latitude: 40.7128,
            longitude: -74.0060,
            giverID: giver.id,
            giverName: giver.displayName,
            giverTrustAtPost: giver.trustScore,
            moderationVerdict: .pass
        )
    }

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
        }
    }
}
