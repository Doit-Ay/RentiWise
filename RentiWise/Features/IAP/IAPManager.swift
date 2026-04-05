//
//  IAPManager.swift
//  RentiWise
//
//  Manages in-app purchase entitlements.
//  Payment processing is handled by Razorpay (see RazorpayPaymentService).
//  This manager handles entitlement checks against the user_entitlements table.
//  Products: Listing Boost (consumable), Lender Pro (subscription), Verified Badge (non-consumable).
//

import Foundation
import Supabase

@MainActor
final class IAPManager {

    static let shared = IAPManager()

    // Product IDs
    static let boostProductId = "com.rentiwise.boost7"
    static let lenderProProductId = "com.rentiwise.lenderpro"
    static let verifiedBadgeProductId = "com.rentiwise.verifiedbadge"

    private init() {}

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
            debugLog("[IAP] Error checking pro status: \(error)")
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

    // MARK: - Private

    private func currentUserId() async -> String? {
        return await SupabaseManager.shared.currentUserId()
    }
}

extension Notification.Name {
    static let iapEntitlementsDidChange = Notification.Name("IAPEntitlementsDidChange")
}
