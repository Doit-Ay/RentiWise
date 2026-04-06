//
//  PhoneVerificationService.swift
//  RentiWise
//
//  Phone OTP via Supabase Edge Function → Twilio SMS.
//  OTP is generated server-side, sent via real SMS, hash stored in DB.
//

import Foundation
import CryptoKit
import Supabase

@MainActor
final class PhoneVerificationService {

    static let shared = PhoneVerificationService()
    private init() {}

    private var cachedVerificationStatus: [String: Bool] = [:]

    // MARK: - Send OTP (real SMS via MSG91)

    func sendOTP(phone: String) async throws {
        let e164 = normalizedE164Phone(phone)

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw VerificationError.notLoggedIn
        }

        debugLog("[PhoneOTP] Sending OTP to \(e164) for user \(userId)")

        // Call edge function — it generates OTP, stores hash, sends SMS
        let payload: [String: String] = ["phone": e164, "user_id": userId]
        
        struct EdgeResponse: Decodable {
            let success: Bool?
            let error: String?
            let message: String?
        }
        
        let edgeResp: EdgeResponse
        do {
            // Decodes directly into EdgeResponse
            edgeResp = try await SupabaseManager.shared.client.functions
                .invoke("send-phone-otp", options: .init(body: payload))
        } catch {
            debugLog("[PhoneOTP] Edge function invocation failed: \(error)")
            throw VerificationError.serverError("Failed to reach OTP service: \(error.localizedDescription)")
        }
            
        if let errString = edgeResp.error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !errString.isEmpty {
            debugLog("[PhoneOTP] Server error: \(errString)")
            throw VerificationError.serverError(errString)
        }

        guard edgeResp.success == true else {
            let message = edgeResp.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw VerificationError.serverError(message?.isEmpty == false ? message! : "Failed to send OTP. Please try again.")
        }

        debugLog("[PhoneOTP] SMS sent successfully to \(e164)")
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

            // Clear OTP
            struct Clear: Encodable { let phone_otp_hash: String?; let phone_otp_expires_at: String? }
            try? await SupabaseManager.shared.client
                .from("users")
                .update(Clear(phone_otp_hash: nil, phone_otp_expires_at: nil))
                .eq("id", value: userId)
                .execute()

            return true
        } catch {
            debugLog("[PhoneOTP] Verify error: \(error)")
            return false
        }
    }

    // MARK: - Mark Phone Verified

    func markPhoneVerified(userId: String, phone: String) async throws {
        let e164 = normalizedE164Phone(phone)

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
    }

    private func normalizedE164Phone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        let localDigits = digits.count > 10 ? String(digits.suffix(10)) : digits
        return "+91\(localDigits)"
    }
}
