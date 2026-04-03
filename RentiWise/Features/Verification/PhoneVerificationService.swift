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

    // MARK: - Send OTP (real SMS via Twilio)

    func sendOTP(phone: String) async throws {
        let e164 = phone.hasPrefix("+91") ? phone : "+91\(phone)"

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw VerificationError.notLoggedIn
        }

        // Call edge function — it generates OTP, stores hash, sends SMS
        let payload: [String: String] = ["phone": e164, "user_id": userId]
        
        struct EdgeResponse: Decodable {
            let success: Bool?
            let error: String?
            let message: String?
        }
        
        // Use the Decodable overload to get the typed response directly
        let responseData: Data = try await SupabaseManager.shared.client.functions
            .invoke("send-phone-otp", options: .init(body: payload))
            
        // Parse the response to check for server-side errors
        if let rawString = String(data: responseData, encoding: .utf8) {
            debugLog("[PhoneOTP] Raw response: \(rawString)")
        }
        
        // Try to decode and check for server-reported errors
        if let edgeResp = try? JSONDecoder().decode(EdgeResponse.self, from: responseData) {
            if let errString = edgeResp.error, !errString.isEmpty {
                throw VerificationError.serverError(errString)
            }
            // success: true — OTP was sent
        }
        // If JSON decode fails, the HTTP status was already 2xx (SDK ensures this),
        // so the edge function returned a non-JSON success. Treat as success.

        debugLog("[PhoneOTP] SMS sent to \(e164)")
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
    }
}
