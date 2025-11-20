//
//  SignInService.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import Foundation
import Supabase

protocol SignInServicing {
    func signIn(credentials: SignInCredentials) async throws -> Session
    func upsertInitialProfile(userId: String, email: String) async throws
}

final class SignInService: SignInServicing {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // Minimal sign-in: call SDK, bubble up its error message.
    func signIn(credentials: SignInCredentials) async throws -> Session {
        do {
            return try await client.auth.signIn(
                email: credentials.email,
                password: credentials.password
            )
        } catch {
            // Show a simple, user-friendly message while keeping original description if available
            let message: String
            if let authError = error as? AuthError {
                message = authError.errorDescription ?? "Sign-in failed. Please check your email and password."
            } else if let httpError = error as? HTTPError {
                message = httpError.errorDescription ?? "Network error. Please try again."
            } else {
                message = error.localizedDescription
            }
            throw NSError(domain: "SignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // Simple, idempotent profile creation: insert id/email; ignore "already exists".
    func upsertInitialProfile(userId: String, email: String) async throws {
        let minimal = MinimalUserInsert(id: userId, email: email)
        do {
            _ = try await client
                .from("users")
                .insert(minimal)
                .execute()
        } catch {
            // Ignore conflict if row already exists
            if let httpError = error as? HTTPError, httpError.response.statusCode == 409 {
                return
            }
            if let postgrestError = error as? PostgrestError {
                let lower = postgrestError.localizedDescription.lowercased()
                if lower.contains("duplicate key value") || lower.contains("conflict") {
                    return
                }
            }
            // Otherwise, bubble up a simple message
            let message = (error as NSError).localizedDescription
            throw NSError(domain: "ProfileUpsert", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

