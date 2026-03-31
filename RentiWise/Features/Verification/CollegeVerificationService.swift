//
//  CollegeVerificationService.swift
//  RentiWise
//
//  Email OTP via Supabase Edge Function → Resend email API.
//  OTP is generated server-side, sent via real email, hash stored in DB.
//

import Foundation
import CryptoKit
import Supabase

@MainActor
final class CollegeVerificationService {

    static let shared = CollegeVerificationService()
    private init() {}

    private var cachedVerificationStatus: [String: Bool] = [:]

    // MARK: - Check Verification

    func isUserVerified(userId: String) async -> Bool {
        if let cached = cachedVerificationStatus[userId] { return cached }
        do {
            struct Row: Decodable { let is_college_verified: Bool? }
            let resp = try await SupabaseManager.shared.client
                .from("users").select("is_college_verified")
                .eq("id", value: userId).single().execute()
            let v = (try? JSONDecoder().decode(Row.self, from: resp.data))?.is_college_verified ?? false
            cachedVerificationStatus[userId] = v
            return v
        } catch { return false }
    }

    // MARK: - Send OTP (real email via Resend)

    func sendVerificationOTP(email: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw VerificationError.notLoggedIn
        }

        // Call edge function — it generates OTP, stores hash, sends email
        let payload: [String: String] = ["email": email, "user_id": userId]
        try await SupabaseManager.shared.client.functions
            .invoke("send-email-otp", options: .init(body: payload))

        print("[EmailOTP] Email sent to \(email)")
    }

    // MARK: - Verify OTP

    func verifyOTP(email: String, otp: String) async throws -> Bool {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return false }

        struct OTPRow: Decodable {
            let email_otp_hash: String?
            let email_otp_expires_at: String?
        }

        do {
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("email_otp_hash, email_otp_expires_at")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(OTPRow.self, from: resp.data)

            // Check expiry
            if let exp = row.email_otp_expires_at,
               let date = ISO8601DateFormatter().date(from: exp),
               Date() > date {
                return false
            }

            // Check hash
            guard otp.sha256Hex() == row.email_otp_hash else { return false }

            // Clear OTP
            struct Clear: Encodable { let email_otp_hash: String?; let email_otp_expires_at: String? }
            try? await SupabaseManager.shared.client
                .from("users")
                .update(Clear(email_otp_hash: nil, email_otp_expires_at: nil))
                .eq("id", value: userId)
                .execute()

            return true
        } catch {
            print("[EmailOTP] Verify error: \(error)")
            return false
        }
    }

    // MARK: - Mark Verified

    func markVerified(userId: String, collegeEmail: String) async throws {
        struct VerUpdate: Encodable {
            let is_college_verified: Bool
            let college_email: String
            let college_verified_at: String
            let verification_level: Int
        }

        var currentLevel = 0
        do {
            struct LevelRow: Decodable { let verification_level: Int? }
            let resp = try await SupabaseManager.shared.client
                .from("users").select("verification_level")
                .eq("id", value: userId).single().execute()
            currentLevel = (try? JSONDecoder().decode(LevelRow.self, from: resp.data))?.verification_level ?? 0
        } catch {}

        let update = VerUpdate(
            is_college_verified: true,
            college_email: collegeEmail,
            college_verified_at: ISO8601DateFormatter().string(from: Date()),
            verification_level: max(currentLevel, 2)
        )

        try await SupabaseManager.shared.client
            .from("users").update(update).eq("id", value: userId).execute()

        cachedVerificationStatus[userId] = true
        try? await SupabaseManager.shared.client.functions
            .invoke("recalculate-trust-score", options: .init(body: ["user_id": userId]))
    }

    func clearCache() {
        cachedVerificationStatus.removeAll()
    }
}

// MARK: - Shared

enum VerificationError: LocalizedError {
    case notLoggedIn
    case serverError(String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "You must be logged in to verify."
        case .serverError(let msg): return msg
        }
    }
}

extension String {
    func sha256Hex() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
