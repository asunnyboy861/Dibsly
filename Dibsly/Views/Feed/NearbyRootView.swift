import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct NearbyRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @State private var vm = FeedViewModel()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedItem: Item?
    @State private var didCenter = false

    private var items: [Item] {
        vm.visibleItems(allItems, origin: env.location.coordinate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                content
            }
            .background(DesignSystem.groupedSurface)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
        .task {
            await vm.refresh(env: env)
        }
        .onAppear {
            guard !didCenter else { return }
            didCenter = true
            centerCamera()
        }
        .refreshable {
            await vm.refresh(env: env)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(env.location.city.isEmpty ? "Nearby" : env.location.city)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DesignSystem.green)
                            .frame(width: 7, height: 7)
                        Text(items.isEmpty ? "Listening for new posts" : "\(items.count) live · worth $\(vm.totalValue(items))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Picker("View", selection: $vm.mode) {
                    Image(systemName: "map.fill").tag(FeedMode.map)
                    Image(systemName: "list.bullet").tag(FeedMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 108)
                .accessibilityLabel("Map or list view")
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search free stuff", text: $vm.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DesignSystem.card))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AllCategoryChip(isSelected: vm.selectedCategory == nil) {
                        vm.selectedCategory = nil
                    }
                    ForEach(ItemCategory.allCases) { category in
                        CategoryChip(category: category, isSelected: vm.selectedCategory == category) {
                            vm.selectedCategory = vm.selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(DesignSystem.groupedSurface)
    }

    @ViewBuilder
    private var content: some View {
        if vm.mode == .map {
            mapContent
        } else {
            listContent
        }
    }

    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                ForEach(items) { item in
                    Annotation("", coordinate: coordinate(for: item)) {
                        PinCardView(item: item) {
                            selectedItem = item
                        }
                    }
                }
                if env.location.hasRealLocation {
                    UserAnnotation()
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
                }

                if items.isEmpty {
                    EmptyStateView(
                        symbol: "sparkles",
                        title: "No free items here yet",
                        message: "Stuff gets posted every few minutes near you. Be the first to give something away and start the block.",
                        actionTitle: "Refresh map",
                        action: { Task { await vm.refresh(env: env) } }
                    )
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 600)
                } else if let selected = selectedItem {
                    ItemPeekCard(item: selected, distance: vm.distanceText(for: selected, origin: env.location.coordinate)) {
                        selectedItem = selected
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 600)
                }
            }
            .padding(.bottom, 18)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await vm.refresh(env: env) }
            } label: {
                Image(systemName: vm.isRefreshing ? "arrow.triangle.2.circlepath" : "location.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(12)
                    .background(Circle().fill(DesignSystem.card))
                    .foregroundStyle(DesignSystem.green)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
            .accessibilityLabel("Refresh nearby items")
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "shippingbox",
                        title: "The block is quiet",
                        message: "No free items match your filters yet. Widen the distance or clear the category.",
                        actionTitle: "Clear filters",
                        action: {
                            vm.selectedCategory = nil
                            vm.searchText = ""
                            vm.radiusKm = 40
                        }
                    )
                    .padding(.top, 24)
                }

                ForEach(items) { item in
                    ListItemCard(item: item, distance: vm.distanceText(for: item, origin: env.location.coordinate)) {
                        selectedItem = item
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func coordinate(for item: Item) -> CLLocationCoordinate2D {
        let fuzzy = item.fuzzyCoordinate
        return CLLocationCoordinate2D(latitude: fuzzy.latitude, longitude: fuzzy.longitude)
    }

    private func centerCamera() {
        let coordinate = env.location.coordinate
        camera = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
        ))
    }
}

struct PinCardView: View {
    let item: Item
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ItemThumbnail(item: item, size: 58, corner: 14)
                    .overlay(alignment: .topTrailing) {
                        if item.isHighValue {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(DesignSystem.orange))
                                .offset(x: 6, y: -6)
                        }
                    }
                Text("worth ~$\(item.valueDollars)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DesignSystem.card))
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignSystem.card.opacity(0.6)))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), worth about \(item.valueDollars) dollars")
    }
}

struct ItemPeekCard: View {
    let item: Item
    let distance: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ItemThumbnail(item: item, size: 64, corner: 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(distance)
                        Text("·")
                        Text(TimeFormat.relative(item.createdAt))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ValueRibbon(dollars: item.valueDollars)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignSystem.card))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct ListItemCard: View {
    let item: Item
    let distance: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let name = item.photoFileNames.first, let image = ImageStore.shared.load(name) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            DesignSystem.surface
                            Image(systemName: item.categorySymbol)
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        if item.isHighValue {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.orange)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(distance)
                        Text("·")
                        Text(item.city.isEmpty ? "Nearby" : item.city)
                        Text("·")
                        Text(TimeFormat.relative(item.createdAt))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    HStack {
                        ValueRibbon(dollars: item.valueDollars)
                        Spacer()
                        TrustBadgeView(score: item.giverTrustAtPost, compact: true)
                    }
                }
                .padding(14)
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignSystem.card))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.details)")
    }
}
