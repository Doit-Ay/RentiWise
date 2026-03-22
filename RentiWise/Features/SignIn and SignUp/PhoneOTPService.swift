//
//  PhoneOTPService.swift
//  RentiWise
//
//  Created by admin99 on 22/03/26.
//

import Foundation
import Supabase

/// Service for sending and verifying phone OTPs via Supabase Auth (Twilio under the hood).
final class PhoneOTPService {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Send OTP

    /// Updates the current user's phone number, which triggers Supabase to send an SMS OTP via Twilio.
    /// Phone must be in E.164 format, e.g. "+919876543210".
    func sendOTP(phone: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(phone: phone))
    }

    // MARK: - Verify OTP

    /// Verifies the SMS OTP code the user received.
    /// On success the phone is confirmed on the auth.users record.
    func verifyOTP(phone: String, token: String) async throws {
        _ = try await client.auth.verifyOTP(
            phone: phone,
            token: token,
            type: .phoneChange
        )
    }

    // MARK: - Mark verified in public.users

    /// Sets `phone_verified = true` on the public.users row and updates the phone number.
    func markPhoneVerified(phone: String) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "PhoneOTP", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        struct VerifyUpdate: Encodable {
            let phone: String
            let is_phone_verified: Bool
        }

        _ = try await client
            .from("users")
            .update(VerifyUpdate(phone: phone, is_phone_verified: true))
            .eq("id", value: userId)
            .execute()
    }
}
