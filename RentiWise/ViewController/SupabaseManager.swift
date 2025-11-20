// SupabaseManager.swift
import Foundation
import Supabase

/// Central singleton to access Supabase services across the app.
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let urlString = "https://assshmccdkktfxqycufv.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzc3NobWNjZGtrdGZ4cXljdWZ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyMjc4NDEsImV4cCI6MjA3ODgwMzg0MX0.x_WZdOdzs3F6juZBJx9tl3e7cM4ycCt__qadpqpxmaI"

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
