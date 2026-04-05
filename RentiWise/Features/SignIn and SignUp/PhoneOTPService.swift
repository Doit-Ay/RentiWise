//
//  PhoneOTPService.swift
//  RentiWise
//
//  Created by admin99 on 22/03/26.
//

import Foundation
import Supabase
import CryptoKit

/// Service for sending and verifying phone OTPs via Edge Function (MSG91).
final class PhoneOTPService {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Send OTP

    /// Triggers Supabase Edge Function to send an SMS OTP via MSG91.
    /// Phone must be in E.164 format, e.g. "+919876543210" or similar as per MSG91 requirements.
    func sendOTP(phone: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "PhoneOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let body: [String: String] = [
            "phone": phone,
            "user_id": userId
        ]
        let _ = try await client.functions.invoke(
            "send-phone-otp",
            options: .init(body: body)
        )
    }

    // MARK: - Verify OTP

    /// Verifies the SMS OTP code the user received by comparing its SHA-256 hash with the DB record.
    func verifyOTP(phone: String, token: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "PhoneOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        struct UserOTPData: Decodable {
            let phone_otp_hash: String?
            let phone_otp_expires_at: String?
        }
        
        // Fetch hash from public.users
        let response = try await client.from("users")
            .select("phone_otp_hash, phone_otp_expires_at")
            .eq("id", value: userId)
            .single()
            .execute()
        
        let data = try JSONDecoder().decode(UserOTPData.self, from: response.data)
        
        guard let userHash = data.phone_otp_hash, let expiresString = data.phone_otp_expires_at else {
            throw NSError(domain: "PhoneOTP", code: 2, userInfo: [NSLocalizedDescriptionKey: "No OTP was sent"])
        }
        
        // Check expiry (Supabase returns ISO8601 strings usually like "2026-04-05T01:05:10+05:30" or "...Z")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var expiryDate = formatter.date(from: expiresString)
        if expiryDate == nil {
            expiryDate = ISO8601DateFormatter().date(from: expiresString)
        }
        guard let finalExpiry = expiryDate else {
            throw NSError(domain: "PhoneOTP", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid OTP expiry format from server"])
        }
        
        if Date() > finalExpiry {
             throw NSError(domain: "PhoneOTP", code: 4, userInfo: [NSLocalizedDescriptionKey: "OTP has expired"])
        }
        
        // Hash token and compare
        let inputData = Data(token.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        
        if hashString != userHash {
            throw NSError(domain: "PhoneOTP", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid OTP"])
        }
    }

    // MARK: - Mark verified in public.users

    /// Sets `phone_verified = true` on the public.users row, updates the phone number, and clears the OTP.
    func markPhoneVerified(phone: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "PhoneOTP", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        struct VerifyUpdate: Encodable {
            let phone: String
            let is_phone_verified: Bool
            let phone_otp_hash: String?
            let phone_otp_expires_at: String?
        }

        let updateData = VerifyUpdate(
            phone: phone, 
            is_phone_verified: true, 
            phone_otp_hash: nil, 
            phone_otp_expires_at: nil
        )

        _ = try await client
            .from("users")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }
}
