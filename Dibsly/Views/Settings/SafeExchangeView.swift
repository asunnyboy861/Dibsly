import MapKit
import SwiftUI

struct SafeExchangeView: View {
    @Environment(AppEnvironment.self) private var env
    let item: Item

    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var results: [MKMapItem] = []
    @State private var isLoading: Bool = false
    @State private var didSearch: Bool = false

    private var itemCoordinate: CLLocationCoordinate2D {
        let fuzzy = item.fuzzyCoordinate
        if fuzzy.latitude == 0 && fuzzy.longitude == 0 {
            return env.location.coordinate
        }
        return CLLocationCoordinate2D(latitude: fuzzy.latitude, longitude: fuzzy.longitude)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera) {
                    ForEach(results, id: \.self) { mapItem in
                        Marker(
                            mapItem.name ?? "Safe spot",
                            coordinate: mapItem.placemark.coordinate
                        )
                        .tint(DesignSystem.green)
                    }
                }
                .frame(height: 250)
                .mapStyle(.standard(elevation: .flat))

                ScrollView {
                    VStack(spacing: 14) {
                        checklistCard
                        resultsCard
                    }
                    .padding(16)
                }
                .background(DesignSystem.groupedSurface)
            }
            .navigationTitle("Safe exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            guard !didSearch else { return }
            didSearch = true
            camera = .region(MKCoordinateRegion(
                center: itemCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
            ))
            await search()
        }
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meetup checklist")
                .font(.subheadline.weight(.bold))
            ForEach(ItemDetailViewModel.safetyChecklist, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.green)
                    Text(tip)
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard()
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Public places nearby")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if isLoading { ProgressView() }
            }

            if results.isEmpty && !isLoading {
                Text("No public buildings found nearby. Pick a busy store, cafe or library you both know.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(results.enumerated()), id: \.offset) { _, mapItem in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(DesignSystem.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mapItem.name ?? "Public place")
                            .font(.caption.weight(.semibold))
                        if let address = mapItem.placemark.title {
                            Text(address)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
            }

            Text("Tip: police station parking lots and busy grocery stores are the safest first meetups.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard()
    }

    private func search() async {
        isLoading = true
        defer { isLoading = false }
        let region = MKCoordinateRegion(
            center: itemCoordinate,
            latitudinalMeters: 9000,
            longitudinalMeters: 9000
        )
        let queries = ["police station", "public library"]
        var collected: [MKMapItem] = []

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            let response: MKLocalSearch.Response? = await withCheckedContinuation { continuation in
                MKLocalSearch(request: request).start { result, _ in
                    continuation.resume(returning: result)
                }
            }
            if let items = response?.mapItems {
                collected.append(contentsOf: items)
            }
        }

        var seen = Set<String>()
        results = collected.filter { mapItem in
            let name = mapItem.name ?? ""
            guard !name.isEmpty, !seen.contains(name) else { return false }
            seen.insert(name)
            return true
        }
        .prefix(8)
        .map { $0 }
    }
}
