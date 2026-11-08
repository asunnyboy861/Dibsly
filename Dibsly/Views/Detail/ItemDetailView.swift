import SwiftUI
import UIKit

struct ItemDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var vm = ItemDetailViewModel()
    @State private var showChat = false
    @State private var showPaywall = false
    @State private var showSafeExchange = false
    @State private var showReportDialog = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var didLoad = false

    private var isOwner: Bool {
        env.profile?.id == item.giverID
    }

    private var isTaker: Bool {
        env.profile?.id == item.dibsByID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    photoCarousel
                    titleBlock
                    statusBanner
                    actionArea
                    giverBlock
                    safetyBlock
                    similarBlock
                }
                .padding(16)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Free item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportDialog = true
                        } label: {
                            Label("Report listing", systemImage: "flag")
                        }
                        Button {
                            Task { await buildShare() }
                        } label: {
                            Label("Share this haul", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .sheet(isPresented: $showChat) {
                ChatView(item: item)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showSafeExchange) {
                SafeExchangeView(item: item)
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ActivityView(items: [shareURL, "I saved money with Dibsly."])
                }
            }
            .confirmationDialog("Report this listing", isPresented: $showReportDialog, titleVisibility: .visible) {
                Button("Scam or misleading") { vm.report(item: item, reason: "Scam or misleading", env: env) }
                Button("Commercial resale") { vm.report(item: item, reason: "Commercial resale", env: env) }
                Button("Unsafe or prohibited") { vm.report(item: item, reason: "Unsafe or prohibited", env: env) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Can't claim this", isPresented: Binding(
                get: { vm.claimError != nil },
                set: { if !$0 { vm.claimError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.claimError ?? "")
            }
        }
        .overlay {
            if vm.showCelebration {
                ClaimSuccessView(item: item) {
                    vm.showCelebration = false
                    showChat = true
                } onClose: {
                    vm.showCelebration = false
                }
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            vm.load(item: item, env: env)
        }
    }

    private var photoCarousel: some View {
        Group {
            if item.photoFileNames.isEmpty {
                ZStack {
                    DesignSystem.surface
                    Image(systemName: item.categorySymbol)
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }
            } else {
                TabView {
                    ForEach(item.photoFileNames, id: \.self) { name in
                        Group {
                            if let image = ImageStore.shared.load(name) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    DesignSystem.surface
                                    Image(systemName: item.categorySymbol)
                                        .font(.system(size: 50))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: item.photoFileNames.count > 1 ? .always : .never))
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            ValueRibbon(dollars: item.valueDollars)
                .padding(10)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 6) {
                Label(item.category.title, systemImage: item.categorySymbol)
                Text("·")
                Text(TimeFormat.relative(item.createdAt))
                Spacer()
                TrustBadgeView(score: item.giverTrustAtPost, compact: true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !item.details.isEmpty {
                Text(item.details)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Text("AI estimate, not an appraisal. Items are free.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard()
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let message = vm.statusMessage {
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DesignSystem.greenDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.green.opacity(0.12)))
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if isOwner {
            ownerActions
        } else if item.status == .live {
            VStack(spacing: 10) {
                DibsButton(
                    title: "DIBS!",
                    subtitle: item.isHighValue ? "Pro neighbors get the 60-second head start" : "It's free. First dibs wins.",
                    isEnabled: !vm.isClaiming
                ) {
                    Task { await vm.claim(item: item, env: env) }
                }
                if vm.requiresPro {
                    Button("See what Pro unlocks") { showPaywall = true }
                        .buttonStyle(DibsSecondaryButtonStyle())
                }
                Text("Calling dibs holds the item for 10 minutes so you can message the giver.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if isTaker {
            takerActions
        } else {
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .dibsCard(padding: 14)
        }
    }

    private var statusText: String {
        switch item.status {
        case .dibbed: return "\(item.dibsByName ?? "Someone") called dibs."
        case .given: return "Handed over. Waiting for confirmation."
        case .done: return "This item found a new home."
        case .humanQueue: return "This listing is in trust and safety review."
        case .archived: return "This listing was removed."
        default: return "This item is no longer available."
        }
    }

    @ViewBuilder
    private var ownerActions: some View {
        VStack(spacing: 12) {
            if item.status == .dibbed || item.status == .meeting {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dibs by \(item.dibsByName ?? "a neighbor")")
                        .font(.headline)
                    if let expires = item.dibsExpiresAt {
                        Text("Window ends \(TimeFormat.relative(expires))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dibsCard(padding: 14)

                Button("Message the neighbor") { showChat = true }
                    .buttonStyle(DibsSecondaryButtonStyle())

                Button("Mark given") {
                    vm.markGiven(item: item, env: env)
                }
                .buttonStyle(DibsPrimaryButtonStyle())

                Button("They never showed up") {
                    if let claim = vm.claims.first, let profile = env.profile {
                        vm.markNoShow(item: item, claim: claim, env: env)
                        env.trust.apply(.noShow, to: profile, context: env.context, note: "Released \(item.title)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Live and waiting for dibs")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dibsCard(padding: 14)

                Button("Take it down") {
                    vm.archive(item: item, env: env)
                }
                .buttonStyle(DibsSecondaryButtonStyle())
            }

            if !vm.claims.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claim requests")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(vm.claims) { claim in
                        HStack {
                            Text(claim.takerName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if claim.takerID == item.dibsByID {
                                Text("Accepted")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.green)
                            } else {
                                Button("Accept") {
                                    vm.accept(claimant: claim, item: item, env: env)
                                }
                                .font(.caption.weight(.bold))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dibsCard(padding: 14)
            }
        }
    }

    @ViewBuilder
    private var takerActions: some View {
        VStack(spacing: 12) {
            if item.status == .dibbed {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    CountdownBar(remaining: item.dibsRemaining, total: 600)
                        .dibsCard(padding: 14)
                }
            }

            if item.status == .given {
                Button("I received it") {
                    vm.confirmReceived(item: item, env: env)
                }
                .buttonStyle(DibsPrimaryButtonStyle())
            }

            Button("Message the giver") { showChat = true }
                .buttonStyle(DibsSecondaryButtonStyle())
        }
    }

    private var giverBlock: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(DesignSystem.green.opacity(0.15))
                Text(String(item.giverName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(DesignSystem.greenDeep)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.giverName)
                    .font(.subheadline.weight(.semibold))
                Text(item.city.isEmpty ? "This neighborhood" : item.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TrustBadgeView(score: item.giverTrustAtPost, compact: true)
        }
        .dibsCard(padding: 14)
    }

    private var safetyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(DesignSystem.green)
                Text("Safe exchange")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }
            Text("Meet in a public place, bring a friend, and never pay a deposit for a free item.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Find a safe exchange spot") {
                showSafeExchange = true
            }
            .buttonStyle(DibsSecondaryButtonStyle())
        }
        .dibsCard(padding: 14)
    }

    private var similarBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More free stuff nearby")
                .font(.subheadline.weight(.bold))
            if vm.similarItems.isEmpty {
                Text("Nothing else nearby yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.similarItems) { similar in
                            VStack(alignment: .leading, spacing: 6) {
                                ItemThumbnail(item: similar, size: 120, corner: 14)
                                Text(similar.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                Text("worth ~$\(similar.valueDollars)")
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.green)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard(padding: 14)
    }

    private func buildShare() async {
        let photo = item.photoFileNames.compactMap { ImageStore.shared.load($0) }.first
        let cents = item.status == .done ? item.estValueCents : item.estValueCents
        guard let image = ShareCardRenderer.render(
            title: item.title,
            savedCents: cents,
            photo: photo,
            badgeText: "Save money, give more"
        ) else { return }
        shareURL = ShareCardRenderer.writeTemporary(image)
        showShare = shareURL != nil
    }
}

struct ClaimSuccessView: View {
    let item: Item
    let onChat: () -> Void
    let onClose: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            ConfettiView(isActive: true)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 54))
                Text("YOU GOT DIBS!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(DesignSystem.green)
                    .multilineTextAlignment(.center)
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("You have 10 minutes to message the giver and lock a public meetup spot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Message the giver", action: onChat)
                    .buttonStyle(DibsPrimaryButtonStyle())
                Button("Back to browsing", action: onClose)
                    .buttonStyle(DibsSecondaryButtonStyle())
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(DesignSystem.card))
            .padding(30)
            .scaleEffect(appear ? 1 : 0.75)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { appear = true }
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
