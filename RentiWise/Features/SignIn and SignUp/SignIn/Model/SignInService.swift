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
    func upsertInitialProfile(userId: String, email: String?, fullName: String?) async throws
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Session
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

    // Google Sign-In via Supabase: exchange Google tokens for a Supabase session
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Session {
        do {
            // Supabase iOS supports exchanging OAuth provider tokens via signInWithIdToken
            // Provider: .google, supply both idToken and accessToken
            return try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
        } catch {
            // Normalize common errors to a user-friendly message
            let message: String
            if let authError = error as? AuthError {
                message = authError.errorDescription ?? "Google sign-in failed. Please try again."
            } else if let httpError = error as? HTTPError {
                message = httpError.errorDescription ?? "Network error. Please try again."
            } else {
                message = (error as NSError).localizedDescription
            }
            throw NSError(domain: "SignInGoogle", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // Simple, idempotent profile creation: insert id/email; ignore "already exists".
    func upsertInitialProfile(userId: String, email: String?, fullName: String?) async throws {
        struct MinimalPublicProfileInsert: Encodable {
            let id: String
            let full_name: String?
        }

        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedEmail = (normalizedEmail?.isEmpty == false) ? normalizedEmail : nil
        let sanitizedFullName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedFullName = (sanitizedFullName?.isEmpty == false)
            ? sanitizedFullName
            : sanitizedEmail?.split(separator: "@").first.map(String.init)
        do {
            if let sanitizedEmail {
                let minimal = MinimalUserInsert(id: userId, email: sanitizedEmail)
                _ = try await client
                    .from("users")
                    .upsert(minimal)
                    .execute()
            }

            _ = try await client
                .from("user_profiles")
                .upsert(MinimalPublicProfileInsert(id: userId, full_name: resolvedFullName))
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
