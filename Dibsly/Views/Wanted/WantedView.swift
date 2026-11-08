import SwiftData
import SwiftUI

struct WantedView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \WantedPost.createdAt, order: .reverse) private var posts: [WantedPost]
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var vm = WantedViewModel()
    @State private var selectedItem: Item?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    intro
                    composer
                    if !posts.isEmpty {
                        postsList
                    }
                }
                .padding(16)
                .padding(.bottom, 48)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Wanted")
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the neighborhood")
                        .font(.headline)
                    Text("Describe what you need. We match it against every new free post.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard()
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("e.g. toddler high chair, or a desk lamp", text: $vm.rawText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Wanted description")

            Button {
                Task { _ = await vm.create(env: env) }
            } label: {
                HStack {
                    if vm.isMatching { ProgressView().tint(.white) }
                    Text(vm.isMatching ? "Looking..." : "Post wanted request")
                }
            }
            .buttonStyle(DibsPrimaryButtonStyle())
            .disabled(vm.isMatching)

            if let message = vm.matchMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.greenDeep)
            }
        }
        .dibsCard()
    }

    private var postsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your requests")
                .font(.subheadline.weight(.bold))

            ForEach(posts) { post in
                let matches = vm.matches(for: post, items: items)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(post.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(post.matchedItemID == nil ? "Watching" : "Matched")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(post.matchedItemID == nil ? .secondary : DesignSystem.green)
                    }
                    Text(TimeFormat.relative(post.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !matches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(matches) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ItemThumbnail(item: item, size: 88, corner: 12)
                                            Text(item.title)
                                                .font(.caption2.weight(.semibold))
                                                .lineLimit(1)
                                                .frame(width: 88, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dibsCard(padding: 14)
            }
        }
    }
}
