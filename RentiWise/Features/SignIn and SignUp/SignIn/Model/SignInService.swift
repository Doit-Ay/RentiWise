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
}

final class SignInService: SignInServicing {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    private func userFacingMessage(for error: Error) -> String {
        let rawDescription: String
        if let authError = error as? AuthError {
            rawDescription = authError.errorDescription ?? error.localizedDescription
        } else if let httpError = error as? HTTPError {
            rawDescription = httpError.errorDescription ?? error.localizedDescription
        } else {
            rawDescription = error.localizedDescription
        }

        let normalized = rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()

        if lowercased.contains("invalid login credentials") {
            return "Invalid login credentials. Reset the password if needed, and make sure this email exists in Supabase Auth for the current project."
        }

        if lowercased.contains("email not confirmed") {
            return "Email not confirmed. Open the verification email first, then try signing in again."
        }

        if lowercased.contains("network") || lowercased.contains("offline") {
            return "Network error. Please check your internet connection and try again."
        }

        return normalized.isEmpty ? "Sign-in failed. Please try again." : normalized
    }

    // Minimal sign-in: call SDK, bubble up its error message.
    func signIn(credentials: SignInCredentials) async throws -> Session {
        do {
            return try await client.auth.signIn(
                email: credentials.email,
                password: credentials.password
            )
        } catch {
            let projectHost = SupabaseManager.shared.projectURL.host ?? "unknown-project"
            let nsError = error as NSError
            debugLog("[Auth.SignIn] Failed for email=\(credentials.email.lowercased()) project=\(projectHost) type=\(String(describing: type(of: error))) code=\(nsError.code) message=\(nsError.localizedDescription)")

            let message = userFacingMessage(for: error)
            throw NSError(domain: "SignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
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
        let resolvedFullName = (sanitizedFullName?.isEmpty == false) ? sanitizedFullName : nil

        do {
            if let sanitizedEmail {
                let minimal = MinimalUserInsert(id: userId, email: sanitizedEmail)
                _ = try await client
                    .from("users")
                    .insert(minimal) // Use insert instead of upsert to avoid overwriting existing data
                    .execute()
            }

            _ = try await client
                .from("user_profiles")
                .insert(MinimalPublicProfileInsert(id: userId, full_name: resolvedFullName)) // Use insert
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
