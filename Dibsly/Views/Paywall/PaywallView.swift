import SwiftData
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @StateObject private var purchase = PurchaseManager.shared
    @State private var vm = PaywallViewModel()

    private let policyBase = "https://asunnyboy861.github.io/Dibsly"

    private var todaysItems: [Item] {
        items.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var monthlyPrice: String {
        purchase.displayPrice(for: PurchaseManager.monthlyID)
    }

    private var yearlyPrice: String {
        purchase.displayPrice(for: PurchaseManager.yearlyID)
    }

    private var lifetimePrice: String {
        purchase.displayPrice(for: PurchaseManager.lifetimeID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    tiers
                    creditsSection
                    purchaseButton
                    legalBlock
                }
                .padding(18)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Dibsly Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.orange)
            Text(purchase.isPro ? "You're already Pro" : "Never miss the good stuff")
                .font(.system(.title, design: .rounded, weight: .black))
                .multilineTextAlignment(.center)
            Text(todaysItems.isEmpty
                 ? "Free items get claimed fast. Pro neighbors see them first."
                 : "\(todaysItems.count) free items were posted near you today. Pro sees them first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [DesignSystem.green, DesignSystem.greenDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .foregroundStyle(.white)
    }

    private var tiers: some View {
        VStack(spacing: 10) {
            tierRow(
                id: PurchaseManager.monthlyID,
                title: "Monthly",
                price: monthlyPrice,
                detail: "7-day free trial, cancel anytime"
            )
            tierRow(
                id: PurchaseManager.yearlyID,
                title: "Annual",
                price: yearlyPrice,
                detail: "Best value for a full year"
            )

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lifetime")
                        .font(.subheadline.weight(.bold))
                    Text("One payment, all Pro features forever")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        let success = await vm.purchaseCredits(productID: PurchaseManager.lifetimeID)
                        if success { dismiss() }
                    }
                } label: {
                    Text(lifetimePrice)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(DesignSystem.green.opacity(0.12)))
                        .foregroundStyle(DesignSystem.greenDeep)
                }
                .buttonStyle(.plain)
                .disabled(vm.isPurchasing)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignSystem.card))
        }
    }

    private func tierRow(id: String, title: String, price: String, detail: String) -> some View {
        Button {
            vm.selectedID = id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: vm.selectedID == id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(DesignSystem.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(DesignSystem.greenDeep)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignSystem.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(vm.selectedID == id ? DesignSystem.green : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cloud AI credits")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(purchase.credits) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Credits run photo moderation, market valuation and Wanted matching. On-device AI never uses credits.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    Task { _ = await vm.purchaseCredits(productID: PurchaseManager.credits100ID) }
                } label: {
                    VStack(spacing: 2) {
                        Text("100 credits")
                            .font(.caption.weight(.bold))
                        Text(purchase.displayPrice(for: PurchaseManager.credits100ID))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(DibsSecondaryButtonStyle())

                Button {
                    Task { _ = await vm.purchaseCredits(productID: PurchaseManager.credits500ID) }
                } label: {
                    VStack(spacing: 2) {
                        Text("500 credits")
                            .font(.caption.weight(.bold))
                        Text(purchase.displayPrice(for: PurchaseManager.credits500ID))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(DibsSecondaryButtonStyle())
            }
        }
        .dibsCard()
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    let success = await vm.purchaseSelected()
                    if success { dismiss() }
                }
            } label: {
                HStack {
                    if vm.isPurchasing { ProgressView().tint(.white) }
                    Text(vm.isPurchasing ? "Purchasing..." : "Start 7-day free trial")
                }
            }
            .buttonStyle(DibsPrimaryButtonStyle())
            .disabled(vm.isPurchasing)

            if let message = vm.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.orange)
                    .multilineTextAlignment(.center)
            }

            Button("Restore purchases") {
                Task { await purchase.restorePurchases() }
            }
            .font(.caption)

            Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                .font(.caption)
        }
    }

    private var legalBlock: some View {
        VStack(spacing: 8) {
            Text("Monthly \(monthlyPrice) after the 7-day trial, annual \(yearlyPrice). Subscriptions renew automatically unless canceled at least 24 hours before the end of the period. Manage or cancel in your App Store account.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Link("Privacy Policy", destination: URL(string: "\(policyBase)/privacy.html")!)
                Link("Terms of Use", destination: URL(string: "\(policyBase)/terms.html")!)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DesignSystem.greenDeep)
        }
        .padding(.top, 4)
    }
}
