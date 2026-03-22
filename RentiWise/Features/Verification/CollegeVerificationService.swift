//
//  CollegeVerificationService.swift
//  RentiWise
//
//  Self-managed email OTP — no Supabase magic links.
//  Generates 6-digit code, stores SHA-256 hash in users table.
//  OTP is shown on-screen for testing. For production: add SendGrid/SMTP.
//

import Foundation
import CryptoKit
import Supabase

@MainActor
final class CollegeVerificationService {

    static let shared = CollegeVerificationService()
    private init() {}

    private var cachedVerificationStatus: [String: Bool] = [:]

    /// Last generated OTP — shown on screen during dev/testing
    private(set) var lastGeneratedOTP: String?

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

    // MARK: - Send OTP

    /// Generate a 6-digit OTP for the given email. Returns OTP for display.
    @discardableResult
    func sendVerificationOTP(email: String) async throws -> String {
        let otp = String(format: "%06d", Int.random(in: 0...999999))

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw VerificationError.notLoggedIn
        }

        struct OTPStore: Encodable {
            let college_email: String
            let email_otp_hash: String
            let email_otp_expires_at: String
        }

        let expiresAt = Date().addingTimeInterval(300) // 5 min
        let update = OTPStore(
            college_email: email,
            email_otp_hash: otp.sha256Hex(),
            email_otp_expires_at: ISO8601DateFormatter().string(from: expiresAt)
        )

        try await SupabaseManager.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()

        lastGeneratedOTP = otp
        print("[EmailOTP] Generated for \(email): \(otp)")
        return otp
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
        lastGeneratedOTP = nil
    }
}

// MARK: - Shared Error + SHA-256

enum VerificationError: LocalizedError {
    case notLoggedIn
    var errorDescription: String? { "You must be logged in to verify." }
}

extension String {
    func sha256Hex() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
