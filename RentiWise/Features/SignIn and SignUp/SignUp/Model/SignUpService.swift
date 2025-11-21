//
//  SignUpService.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import Foundation
import Supabase

protocol SignUpServicing {
    func signUp(credentials: SignUpCredentials) async throws -> AuthResponse
    func upsertUserProfile(userId: String, email: String, profile: SignUpUserProfile) async throws
}

final class SignUpService: SignUpServicing {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func signUp(credentials: SignUpCredentials) async throws -> AuthResponse {
        try await client.auth.signUp(email: credentials.email, password: credentials.password)
    }

    func upsertUserProfile(userId: String, email: String, profile: SignUpUserProfile) async throws {
        let payload = SignUpDBUserRow(
            id: userId,
            email: email,
            full_name: profile.fullName,
            phone: profile.phone
        )
        _ = try await client
            .from("users")
            .upsert(payload)
            .execute()
    }
}
