//
//  CollegeVerificationService.swift
//  RentiWise
//
//  Singleton service for college email OTP verification.
//  One-time gate before a user can send their first rental request.
//

import Foundation
import Supabase

@MainActor
final class CollegeVerificationService {

    static let shared = CollegeVerificationService()
    private init() {}

    /// In-memory cache — avoids re-fetching every time user taps "Rent Now"
    private var cachedVerificationStatus: [String: Bool] = [:]

    // MARK: - Check Verification

    func isUserVerified(userId: String) async -> Bool {
        if let cached = cachedVerificationStatus[userId] { return cached }

        do {
            struct VerRow: Decodable { let is_college_verified: Bool? }
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("is_college_verified")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(VerRow.self, from: resp.data)
            let verified = row.is_college_verified ?? false
            cachedVerificationStatus[userId] = verified
            return verified
        } catch {
            print("[CollegeVerification] Error checking status: \(error)")
            return false
        }
    }

    // MARK: - Send OTP

    func sendVerificationOTP(email: String) async throws {
        try await SupabaseManager.shared.client.auth.signInWithOTP(email: email)
        print("[CollegeVerification] OTP sent to \(email)")
    }

    // MARK: - Verify OTP

    func verifyOTP(email: String, otp: String) async throws -> Bool {
        do {
            try await SupabaseManager.shared.client.auth.verifyOTP(
                email: email,
                token: otp,
                type: .email
            )
            return true
        } catch {
            print("[CollegeVerification] OTP verification failed: \(error)")
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

        // Fetch current verification_level for GREATEST logic
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

        let update = VerUpdate(
            is_college_verified: true,
            college_email: collegeEmail,
            college_verified_at: ISO8601DateFormatter().string(from: Date()),
            verification_level: max(currentLevel, 2)
        )

        try await SupabaseManager.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()

        // Update cache
        cachedVerificationStatus[userId] = true

        // Recalculate trust score (+25 for college verification)
        try? await SupabaseManager.shared.client.functions
            .invoke("recalculate-trust-score", options: .init(body: ["user_id": userId]))

        print("[CollegeVerification] User \(userId) marked verified with \(collegeEmail)")
    }

    /// Clear cache (e.g. on logout)
    func clearCache() {
        cachedVerificationStatus.removeAll()
    }
}
