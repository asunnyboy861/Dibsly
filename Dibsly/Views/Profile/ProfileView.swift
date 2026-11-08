import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \TrustEvent.createdAt, order: .reverse) private var allEvents: [TrustEvent]

    @State private var vm = ProfileViewModel()
    @State private var hauls = HaulsViewModel()
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showNameEditor = false

    private var profile: UserProfile? { env.profile }

    private var savedCents: Int {
        guard let profile else { return 0 }
        return hauls.savedCents(hauls.doneClaims(profile: profile, items: allItems))
    }

    private var events: [TrustEvent] {
        guard let profile else { return [] }
        return allEvents.filter { $0.userID == profile.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identityCard
                    statsRow
                    proCard
                    trustSection
                    settingsButton
                }
                .padding(16)
                .padding(.bottom, 48)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Profile")
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Your name", isPresented: $showNameEditor) {
                TextField("Display name", text: $vm.displayNameDraft)
                Button("Save") {
                    if let profile { vm.saveName(profile: profile, env: env) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            if profile == nil { env.bootstrapProfile() }
            if let profile { vm.load(profile: profile, env: env) }
        }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(DesignSystem.green.opacity(0.16))
                Text(String((profile?.displayName ?? "N").prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(DesignSystem.greenDeep)
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(profile?.displayName ?? "Neighbor")
                        .font(.title3.weight(.bold))
                    if PurchaseManager.shared.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.orange))
                    }
                }
                Text(profile?.city.isEmpty == false ? profile!.city : "Your neighborhood")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TrustBadgeView(score: profile?.trustScore ?? 5)
            }

            Spacer()

            Button {
                vm.displayNameDraft = profile?.displayName ?? ""
                showNameEditor = true
            } label: {
                Image(systemName: "pencil")
                    .padding(9)
                    .background(Circle().fill(DesignSystem.surface))
            }
            .accessibilityLabel("Edit display name")
        }
        .dibsCard()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat(value: "$\(savedCents / 100)", label: "Saved")
            stat(value: "\(profile?.trustScore ?? 5)", label: "Trust")
            stat(value: "\(activeCount)", label: "Active")
        }
    }

    private var activeCount: Int {
        guard let profile else { return 0 }
        return hauls.activeCount(profile: profile, items: allItems)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(DesignSystem.greenDeep)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignSystem.card))
    }

    private var proCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(PurchaseManager.shared.isPro ? "Dibsly Pro is active" : "Unlock the quick-grab window")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(PurchaseManager.shared.isPro
                         ? "Unlimited alerts, posting and on-device AI."
                         : "Pro gets the first 60 seconds on high-value free items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .dibsCard()
        }
        .buttonStyle(.plain)
    }

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trust history")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("Newbie → Neighbor → Trusted → Legend")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if events.isEmpty {
                Text("No trust events yet. Complete your first giveaway to start building reputation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(8)) { event in
                    HStack {
                        Image(systemName: event.reason.isPositive ? "plus.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(event.reason.isPositive ? DesignSystem.green : DesignSystem.orange)
                        Text(event.note.isEmpty ? event.reason.label : event.note)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(event.delta > 0 ? "+" : "")\(event.delta)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(event.reason.isPositive ? DesignSystem.green : DesignSystem.orange)
                        Text(TimeFormat.relative(event.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dibsCard()
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(DesignSystem.green)
                Text("Settings, AI and support")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .dibsCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}
