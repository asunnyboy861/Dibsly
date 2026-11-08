import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let monthlyID = "com.zzoutuo.Dibsly.pro.monthly"
    static let yearlyID = "com.zzoutuo.Dibsly.pro.yearly"
    static let lifetimeID = "com.zzoutuo.Dibsly.pro.lifetime"
    static let credits100ID = "com.zzoutuo.Dibsly.credits.100"
    static let credits500ID = "com.zzoutuo.Dibsly.credits.500"

    static let allIDs = [monthlyID, yearlyID, lifetimeID, credits100ID, credits500ID]

    static let fallbackPrices: [String: String] = [
        monthlyID: "$4.99",
        yearlyID: "$34.99",
        lifetimeID: "$59.99",
        credits100ID: "$2.99",
        credits500ID: "$9.99"
    ]

    @Published var isPro: Bool = false
    @Published var credits: Int = 0
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    @Published var lastMessage: String?

    private let creditsKey = "dibsly.ai.credits"
    private var transactionListener: Task<Void, Never>?

    private init() {
        credits = UserDefaults.standard.integer(forKey: creditsKey)
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    var monthlyProduct: Product? { product(for: Self.monthlyID) }
    var yearlyProduct: Product? { product(for: Self.yearlyID) }
    var lifetimeProduct: Product? { product(for: Self.lifetimeID) }
    var credits100Product: Product? { product(for: Self.credits100ID) }
    var credits500Product: Product? { product(for: Self.credits500ID) }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for id: String) -> String {
        product(for: id)?.displayPrice ?? Self.fallbackPrices[id] ?? ""
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            products = loaded.sorted { left, right in
                let leftIndex = Self.allIDs.firstIndex(of: left.id) ?? 99
                let rightIndex = Self.allIDs.firstIndex(of: right.id) ?? 99
                return leftIndex < rightIndex
            }
            if products.isEmpty {
                loadError = "No products returned. Check your network or the App Store configuration."
            } else {
                loadError = nil
            }
        } catch {
            loadError = "Unable to load App Store products. Tap to retry."
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastMessage = "Purchase could not be verified."
                    return false
                }
                await apply(transaction: transaction)
                await transaction.finish()
                return true
            case .userCancelled:
                lastMessage = nil
                return false
            case .pending:
                lastMessage = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    private func apply(transaction: Transaction) async {
        if [Self.monthlyID, Self.yearlyID, Self.lifetimeID].contains(transaction.productID) {
            await refreshEntitlements()
            lastMessage = "Pro unlocked. Enjoy the speed."
        } else if transaction.productID == Self.credits100ID {
            addCredits(100)
            lastMessage = "100 AI credits added."
        } else if transaction.productID == Self.credits500ID {
            addCredits(500)
            lastMessage = "500 AI credits added."
        }
    }

    func refreshEntitlements() async {
        var pro = false
        for id in [Self.monthlyID, Self.yearlyID, Self.lifetimeID] {
            if let result = await Transaction.currentEntitlement(for: id),
               case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastMessage = isPro ? "Purchases restored." : "No previous purchase found."
        } catch {
            loadError = "Restore failed: \(error.localizedDescription)"
        }
    }

    var hasCredits: Bool { credits > 0 }

    func addCredits(_ amount: Int) {
        credits += amount
        UserDefaults.standard.set(credits, forKey: creditsKey)
    }

    @discardableResult
    func spendCredits(_ amount: Int = 1) -> Bool {
        guard credits >= amount else { return false }
        credits -= amount
        UserDefaults.standard.set(credits, forKey: creditsKey)
        return true
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.apply(transaction: transaction)
            }
        }
    }
}
