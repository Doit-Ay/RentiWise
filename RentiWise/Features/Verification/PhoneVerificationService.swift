//
//  PhoneVerificationService.swift
//  RentiWise
//
//  Self-managed phone OTP — no Twilio needed.
//  Generates 6-digit code, stores SHA-256 hash in users table.
//  OTP is shown on-screen for testing. For production: add SMS API.
//

import Foundation
import CryptoKit
import Supabase

@MainActor
final class PhoneVerificationService {

    static let shared = PhoneVerificationService()
    private init() {}

    private var cachedVerificationStatus: [String: Bool] = [:]

    /// Last generated OTP — shown on screen during dev/testing
    private(set) var lastGeneratedOTP: String?

    // MARK: - Send OTP

    /// Generate a 6-digit OTP for the phone number.
    /// Stores hashed OTP in users table. Returns the OTP for display.
    @discardableResult
    func sendOTP(phone: String) async throws -> String {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"
        let otp = String(format: "%06d", Int.random(in: 0...999999))

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw VerificationError.notLoggedIn
        }

        struct OTPStore: Encodable {
            let phone: String
            let phone_otp_hash: String
            let phone_otp_expires_at: String
        }

        let expiresAt = Date().addingTimeInterval(300) // 5 min
        let update = OTPStore(
            phone: e164,
            phone_otp_hash: otp.sha256Hex(),
            phone_otp_expires_at: ISO8601DateFormatter().string(from: expiresAt)
        )

        try await SupabaseManager.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()

        lastGeneratedOTP = otp
        print("[PhoneOTP] Generated for \(e164): \(otp)")
        return otp
    }

    // MARK: - Verify OTP

    func verifyOTP(phone: String, otp: String) async throws -> Bool {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return false }

        struct OTPRow: Decodable {
            let phone_otp_hash: String?
            let phone_otp_expires_at: String?
        }

        do {
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("phone_otp_hash, phone_otp_expires_at")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(OTPRow.self, from: resp.data)

            // Check expiry
            if let exp = row.phone_otp_expires_at,
               let date = ISO8601DateFormatter().date(from: exp),
               Date() > date {
                return false
            }

            // Check hash
            guard otp.sha256Hex() == row.phone_otp_hash else { return false }

            // Clear OTP after success
            struct Clear: Encodable { let phone_otp_hash: String?; let phone_otp_expires_at: String? }
            try? await SupabaseManager.shared.client
                .from("users")
                .update(Clear(phone_otp_hash: nil, phone_otp_expires_at: nil))
                .eq("id", value: userId)
                .execute()

            return true
        } catch {
            print("[PhoneOTP] Verify error: \(error)")
            return false
        }
    }

    // MARK: - Mark Phone Verified

    func markPhoneVerified(userId: String, phone: String) async throws {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"

        struct PhoneUpdate: Encodable {
            let phone: String
            let is_phone_verified: Bool
            let phone_verified_at: String
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

        let update = PhoneUpdate(
            phone: e164,
            is_phone_verified: true,
            phone_verified_at: ISO8601DateFormatter().string(from: Date()),
            verification_level: max(currentLevel, 1)
        )

        try await SupabaseManager.shared.client
            .from("users").update(update).eq("id", value: userId).execute()

        cachedVerificationStatus[userId] = true
        try? await SupabaseManager.shared.client.functions
            .invoke("recalculate-trust-score", options: .init(body: ["user_id": userId]))
    }

    // MARK: - Check

    func isPhoneVerified(userId: String) async -> Bool {
        if let cached = cachedVerificationStatus[userId] { return cached }
        do {
            struct Row: Decodable { let is_phone_verified: Bool? }
            let resp = try await SupabaseManager.shared.client
                .from("users").select("is_phone_verified")
                .eq("id", value: userId).single().execute()
            let v = (try? JSONDecoder().decode(Row.self, from: resp.data))?.is_phone_verified ?? false
            cachedVerificationStatus[userId] = v
            return v
        } catch { return false }
    }

    func clearCache() {
        cachedVerificationStatus.removeAll()
        lastGeneratedOTP = nil
    }
}
