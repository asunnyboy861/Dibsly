import CoreLocation
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class FeedViewModel {
    var mode: FeedMode = .map
    var selectedCategory: ItemCategory?
    var searchText: String = ""
    var radiusKm: Double = 20
    var selectedItemID: String?
    var isRefreshing: Bool = false
    var remoteCount: Int = 0
    var lastRefresh: Date?
    var errorMessage: String?

    func visibleItems(_ all: [Item], origin: CLLocationCoordinate2D) -> [Item] {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return all
            .filter { item in
                item.status == .live
            }
            .filter { item in
                if let selectedCategory, item.category != selectedCategory { return false }
                return true
            }
            .filter { item in
                guard !query.isEmpty else { return true }
                return item.title.lowercased().contains(query)
                    || item.details.lowercased().contains(query)
                    || item.category.title.lowercased().contains(query)
            }
            .filter { item in
                let coordinate = item.fuzzyCoordinate
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                return location.distance(from: originLocation) <= radiusKm * 1000
            }
            .sorted { left, right in
                let leftCoordinate = left.fuzzyCoordinate
                let rightCoordinate = right.fuzzyCoordinate
                let leftLocation = CLLocation(latitude: leftCoordinate.latitude, longitude: leftCoordinate.longitude)
                let rightLocation = CLLocation(latitude: rightCoordinate.latitude, longitude: rightCoordinate.longitude)
                return leftLocation.distance(from: originLocation) < rightLocation.distance(from: originLocation)
            }
    }

    func selectedItem(from all: [Item]) -> Item? {
        guard let selectedItemID else { return nil }
        return all.first { $0.id == selectedItemID }
    }

    func distanceText(for item: Item, origin: CLLocationCoordinate2D) -> String {
        let coordinate = item.fuzzyCoordinate
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let meters = location.distance(from: originLocation)
        let miles = meters / 1609.34
        if miles < 0.1 { return "around the corner" }
        return String(format: "%.1f mi", miles)
    }

    func totalValue(_ items: [Item]) -> Int {
        items.reduce(0) { $0 + $1.estValueCents } / 100
    }

    func refresh(env: AppEnvironment) async {
        isRefreshing = true
        defer { isRefreshing = false }
        await env.cloud.refreshAvailability()
        let remote = await env.cloud.fetchListings()
        merge(remote: remote, context: env.context, fallbackCity: env.location.city)
        remoteCount = remote.count
        lastRefresh = Date()
        if env.cloud.isAvailable && remote.isEmpty {
            errorMessage = nil
        }
    }

    func merge(remote: [RemoteListing], context: ModelContext, fallbackCity: String) {
        let descriptor = FetchDescriptor<Item>()
        let existing = (try? context.fetch(descriptor)) ?? []
        var knownIDs = Set(existing.map { $0.id })
        var didInsert = false

        for listing in remote where !knownIDs.contains(listing.id) {
            let item = Item(
                id: listing.id,
                title: listing.title,
                details: listing.details,
                category: ItemCategory(rawValue: listing.categoryRaw) ?? .other,
                estValueCents: listing.estValueCents,
                photoFileNames: listing.imageName.map { [$0] } ?? [],
                status: .live,
                geohash5: listing.geohash5,
                city: listing.city.isEmpty ? fallbackCity : listing.city,
                latitude: listing.latitude,
                longitude: listing.longitude,
                giverID: listing.giverID,
                giverName: listing.giverName,
                giverTrustAtPost: listing.giverTrust,
                moderationVerdict: .pass,
                isRemote: true
            )
            context.insert(item)
            knownIDs.insert(listing.id)
            didInsert = true
        }

        if didInsert {
            try? context.save()
        }
    }

    func emptyHeadline(_ items: [Item]) -> String {
        if items.isEmpty {
            return "Your neighborhood is quiet right now"
        }
        return "\(items.count) free items nearby"
    }
}
