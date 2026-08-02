import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var transactionListener: Task<Void, Never>?
    static let monthlyProID = "com.bambi2008.echo.pro.monthly"
    static let yearlyProID = "com.bambi2008.echo.pro.yearly"
    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts(); await updatePurchasedProducts() }
    }
    deinit { transactionListener?.cancel() }
    func loadProducts() async {
        isLoading = true; defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: [Self.monthlyProID, Self.yearlyProID])
            await MainActor.run { self.products = storeProducts.sorted { $0.price < $1.price } }
        } catch { await MainActor.run { self.errorMessage = "Failed to load products: \(error.localizedDescription)" } }
    }
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled: return false
        case .pending: return false
        @unknown default: return false
        }
    }
    func restorePurchases() async {
        do { try await AppStore.sync(); await updatePurchasedProducts() }
        catch { await MainActor.run { self.errorMessage = "Restore failed: \(error.localizedDescription)" } }
    }
    var isPro: Bool { purchasedProductIDs.contains(Self.monthlyProID) || purchasedProductIDs.contains(Self.yearlyProID) }
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil { purchased.insert(transaction.productID) }
            }
        }
        await MainActor.run { self.purchasedProductIDs = purchased }
    }
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.verificationFailed
        }
    }
}

enum StoreError: LocalizedError {
    case verificationFailed
    var errorDescription: String? { "Purchase verification failed." }
}
