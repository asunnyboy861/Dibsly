import SwiftData
import SwiftUI
import UIKit

enum HaulTab: String, CaseIterable {
    case claimed = "I claimed"
    case given = "I gave"
}

struct MyHaulsView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @State private var tab: HaulTab = .claimed
    @State private var vm = HaulsViewModel()
    @State private var selectedItem: Item?
    @State private var shareURL: URL?
    @State private var showShare = false

    private var profile: UserProfile? { env.profile }

    private var claimed: [Item] {
        guard let profile else { return [] }
        return vm.claimedItems(profile: profile, items: allItems)
    }

    private var given: [Item] {
        guard let profile else { return [] }
        return vm.givenItems(profile: profile, items: allItems)
    }

    private var visible: [Item] {
        tab == .claimed ? claimed : given
    }

    private var savedCents: Int {
        guard let profile else { return 0 }
        return vm.savedCents(vm.doneClaims(profile: profile, items: allItems))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    Picker("Hauls", selection: $tab) {
                        ForEach(HaulTab.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    if visible.isEmpty {
                        EmptyStateView(
                            symbol: "bag",
                            title: tab == .claimed ? "No hauls yet" : "Nothing given away yet",
                            message: tab == .claimed
                                ? "Call dibs on something nearby and it will land here with the value you saved."
                                : "Post something you no longer need. One neighbor's clutter is another's couch."
                        )
                    } else {
                        grid
                    }
                }
                .padding(16)
                .padding(.bottom, 48)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("My Hauls")
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ActivityView(items: [shareURL])
                }
            }
        }
        .onAppear {
            if profile == nil { env.bootstrapProfile() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You saved")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("$\(savedCents / 100)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 8) {
                Label("\(claimed.count) claimed", systemImage: "bag.fill")
                Text("·")
                Label("\(given.count) given", systemImage: "gift.fill")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [DesignSystem.green, DesignSystem.greenDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(visible) { item in
                VStack(alignment: .leading, spacing: 6) {
                    ItemThumbnail(item: item, size: 150, corner: 14)
                        .frame(maxWidth: .infinity)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(statusLabel(item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("$\(item.valueDollars)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignSystem.green)
                        Spacer()
                        if item.status == .done {
                            Button {
                                makeShare(item)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption.weight(.semibold))
                            }
                            .accessibilityLabel("Share haul")
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignSystem.card))
                .onTapGesture { selectedItem = item }
            }
        }
    }

    private func statusLabel(_ item: Item) -> String {
        switch item.status {
        case .dibbed: return "Dibs called"
        case .given: return "Waiting for confirm"
        case .done: return "Complete"
        default: return item.category.title
        }
    }

    private func makeShare(_ item: Item) {
        let photo = item.photoFileNames.compactMap { ImageStore.shared.load($0) }.first
        guard let image = ShareCardRenderer.render(
            title: item.title,
            savedCents: item.estValueCents,
            photo: photo,
            badgeText: "\(env.displayName) · \(env.badge.title)"
        ) else { return }
        shareURL = ShareCardRenderer.writeTemporary(image)
        showShare = shareURL != nil
    }
}
