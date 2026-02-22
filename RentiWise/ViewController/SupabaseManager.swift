// SupabaseManager.swift
import Foundation
import Supabase

/// Central singleton to access Supabase services across the app.
final class SupabaseManager {
    static let shared = SupabaseManager()

    private static func infoPlistValue(for key: String) -> String {
        guard let val = Bundle.main.object(forInfoDictionaryKey: key) as? String, !val.isEmpty else {
            fatalError("Missing Info.plist key '\(key)'. Add it to Info.plist (or your .xcconfig).")
        }
        return val
    }

    private let urlString = SupabaseManager.infoPlistValue(for: "SUPABASE_URL")
    private let anonKey   = SupabaseManager.infoPlistValue(for: "SUPABASE_ANON_KEY")

    let client: SupabaseClient

    // Public read-only accessors so other parts (like signed upload helper) can use them.
    var projectURL: URL { URL(string: urlString)! }
    var publicAnonKey: String { anonKey }

    private init() {
        let url = URL(string: urlString)!

        let options = SupabaseClientOptions(
            db: .init(),
            auth: .init(emitLocalSessionAsInitialSession: true),
            global: .init(),
            functions: .init(),
            realtime: .init(),
            storage: .init()
        )

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: options
        )
    }

    // MARK: - Small convenience helpers

    /// Synchronous read — returns the cached user ID if a session is already loaded.
    /// Use this in hot paths (e.g. cell configuration) to avoid unnecessary async hops.
    /// Falls back to `nil` if no session is cached yet.
    func currentUserIdSync() -> String? {
        client.auth.currentUser?.id.uuidString
    }

    /// Async version — triggers a network refresh of the session if needed.
    /// Prefer `currentUserIdSync()` when a session is already known to exist.
    func currentUserId() async -> String? {
        do {
            let session = try await client.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func createSignedUrl(bucket: String, path: String, expiresIn: Int = 3600) async -> URL? {
        do {
            let url = try await client
                .storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: expiresIn)
            return url
        } catch {
            print("createSignedUrl error:", error)
            return nil
        }
    }
}
