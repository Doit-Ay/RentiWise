//
//  KYCService.swift
//  RentiWise
//
//  Created by admin99 on 23/03/26.
//

import Foundation
import Supabase

/// Service for managing KYC verification status in Supabase.
final class KYCService {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Fetch KYC Status

    /// Returns the current KYC status string ("none", "pending", "approved", "declined").
    func fetchKYCStatus() async throws -> String {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            return "none"
        }

        struct KYCRow: Decodable {
            let kyc_status: String?
        }

        let response = try await client
            .from("users")
            .select("kyc_status")
            .eq("id", value: userId)
            .single()
            .execute()

        let row = try JSONDecoder().decode(KYCRow.self, from: response.data)
        return row.kyc_status ?? "none"
    }

    // MARK: - Update KYC Status

    /// Updates the KYC status and session ID after a Didit verification attempt.
    func updateKYCStatus(sessionId: String, status: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "KYC", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        struct KYCUpdate: Encodable {
            let kyc_session_id: String
            let kyc_status: String
            let kyc_verified_at: String?
        }

        let verifiedAt: String? = (status == "approved")
            ? ISO8601DateFormatter().string(from: Date())
            : nil

        _ = try await client
            .from("users")
            .update(KYCUpdate(
                kyc_session_id: sessionId,
                kyc_status: status,
                kyc_verified_at: verifiedAt
            ))
            .eq("id", value: userId)
            .execute()
    }
}
