//
//  PhoneVerificationService.swift
//  RentiWise
//
//  Service for mandatory phone OTP verification using Supabase Auth.
//

import Foundation
import Supabase

@MainActor
final class PhoneVerificationService {

    static let shared = PhoneVerificationService()
    private init() {}

    private var cachedVerificationStatus: [String: Bool] = [:]

    // MARK: - Send OTP

    /// Send OTP to phone number. Input: 10-digit number (auto-prepends +91).
    func sendOTP(phone: String) async throws {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"
        try await SupabaseManager.shared.client.auth.signInWithOTP(phone: e164)
        print("[PhoneVerification] OTP sent to \(e164)")
    }

    // MARK: - Verify OTP

    /// Verify the OTP. Returns true on success.
    func verifyOTP(phone: String, otp: String) async throws -> Bool {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"
        do {
            try await SupabaseManager.shared.client.auth.verifyOTP(
                phone: e164,
                token: otp,
                type: .sms
            )
            return true
        } catch {
            print("[PhoneVerification] OTP verification failed: \(error)")
            return false
        }
    }

    // MARK: - Mark Phone Verified

    /// After OTP verified: store phone + mark verified in users table.
    func markPhoneVerified(userId: String, phone: String) async throws {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"

        struct PhoneUpdate: Encodable {
            let phone: String
            let is_phone_verified: Bool
            let phone_verified_at: String
            let verification_level: Int
        }

        // Fetch current verification_level to use GREATEST logic
        var currentLevel = 0
        do {
            struct LevelRow: Decodable { let verification_level: Int? }
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("verification_level")
                .eq("id", value: userId)
                .single()
                .execute()
            let row = try JSONDecoder().decode(LevelRow.self, from: resp.data)
            currentLevel = row.verification_level ?? 0
        } catch { /* use default 0 */ }

        let update = PhoneUpdate(
            phone: e164,
            is_phone_verified: true,
            phone_verified_at: ISO8601DateFormatter().string(from: Date()),
            verification_level: max(currentLevel, 1)
        )

        try await SupabaseManager.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()

        cachedVerificationStatus[userId] = true

        // Recalculate trust score
        try? await SupabaseManager.shared.client.functions
            .invoke("recalculate-trust-score", options: .init(body: ["user_id": userId]))

        print("[PhoneVerification] User \(userId) marked phone verified")
    }

    // MARK: - Check Verification

    func isPhoneVerified(userId: String) async -> Bool {
        if let cached = cachedVerificationStatus[userId] { return cached }

        do {
            struct VerRow: Decodable { let is_phone_verified: Bool? }
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("is_phone_verified")
                .eq("id", value: userId)
                .single()
                .execute()
            let row = try JSONDecoder().decode(VerRow.self, from: resp.data)
            let verified = row.is_phone_verified ?? false
            cachedVerificationStatus[userId] = verified
            return verified
        } catch {
            print("[PhoneVerification] Error checking status: \(error)")
            return false
        }
    }

    /// Clear cache (e.g. on logout)
    func clearCache() {
        cachedVerificationStatus.removeAll()
    }
}
