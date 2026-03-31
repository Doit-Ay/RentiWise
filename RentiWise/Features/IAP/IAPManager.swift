//
//  IAPManager.swift
//  RentiWise
//
//  StoreKit 2 singleton for In-App Purchases.
//  Products: Listing Boost (consumable), Lender Pro (subscription), Verified Badge (non-consumable).
//

import StoreKit
import Supabase

@MainActor
final class IAPManager {

    static let shared = IAPManager()

    // Product IDs
    static let boostProductId = "com.rentiwise.boost7"
    static let lenderProProductId = "com.rentiwise.lenderpro"
    static let verifiedBadgeProductId = "com.rentiwise.verifiedbadge"

    private(set) var products: [Product] = []
    private var updateTask: Task<Void, Never>?

    private init() {
        // Start listening for transaction updates
        updateTask = Task {
            await listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        do {
            let productIds: Set<String> = [
                Self.boostProductId,
                Self.lenderProProductId,
                Self.verifiedBadgeProductId
            ]
            products = try await Product.products(for: productIds)
            print("[IAP] Fetched \(products.count) products")
        } catch {
            print("[IAP] Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // Validate with our server
            await validateWithServer(
                productId: product.id,
                transactionId: String(transaction.id)
            )
            await transaction.finish()
            print("[IAP] Purchase successful: \(product.id)")
            return true

        case .userCancelled:
            print("[IAP] User cancelled purchase")
            return false

        case .pending:
            print("[IAP] Purchase pending (Ask to Buy, etc.)")
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Entitlement Checks

    func isProUser() async -> Bool {
        guard let userId = await currentUserId() else { return false }
        do {
            struct EntRow: Decodable { let id: String }
            let resp = try await SupabaseManager.shared.client
                .from("user_entitlements")
                .select("id")
                .eq("user_id", value: userId)
                .eq("product_id", value: Self.lenderProProductId)
                .eq("is_active", value: true)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .limit(1)
                .execute()
            let rows = try JSONDecoder().decode([EntRow].self, from: resp.data)
            return !rows.isEmpty
        } catch {
            print("[IAP] Error checking pro status: \(error)")
            return false
        }
    }

    func hasBoostedItem(itemId: String) async -> Bool {
        do {
            struct BoostRow: Decodable { let is_boosted: Bool; let boost_expires_at: String? }
            let resp = try await SupabaseManager.shared.client
                .from("items")
                .select("is_boosted, boost_expires_at")
                .eq("id", value: itemId)
                .single()
                .execute()
            let row = try JSONDecoder().decode(BoostRow.self, from: resp.data)
            guard row.is_boosted, let expiresStr = row.boost_expires_at else { return false }
            let formatter = ISO8601DateFormatter()
            if let expiresDate = formatter.date(from: expiresStr) {
                return expiresDate > Date()
            }
            return false
        } catch {
            return false
        }
    }

    func hasVerifiedBadge() async -> Bool {
        guard let userId = await currentUserId() else { return false }
        do {
            struct EntRow: Decodable { let id: String }
            let resp = try await SupabaseManager.shared.client
                .from("user_entitlements")
                .select("id")
                .eq("user_id", value: userId)
                .eq("product_id", value: Self.verifiedBadgeProductId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
            let rows = try JSONDecoder().decode([EntRow].self, from: resp.data)
            return !rows.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Product Helpers

    func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await validateWithServer(
                    productId: transaction.productID,
                    transactionId: String(transaction.id)
                )
                await transaction.finish()
            } catch {
                print("[IAP] Transaction update error: \(error)")
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }

    private func validateWithServer(productId: String, transactionId: String) async {
        guard let userId = await currentUserId() else { return }
        do {
            let body: [String: String] = [
                "user_id": userId,
                "product_id": productId,
                "transaction_id": transactionId,
            ]
            try await SupabaseManager.shared.client.functions.invoke(
                "validate-iap-receipt",
                options: .init(body: body)
            )
            print("[IAP] Server validation complete for \(productId)")
        } catch {
            print("[IAP] Server validation failed: \(error)")
        }
    }

    private func currentUserId() async -> String? {
        return await SupabaseManager.shared.currentUserId()
    }
}
