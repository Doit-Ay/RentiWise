// SupabaseManager.swift
import Foundation
import Supabase

/// Central singleton to access Supabase services across the app.
final class SupabaseManager {
    static let shared = SupabaseManager()

    private static let fallbackSupabaseURL = "https://example.com"

    private static var safeFallbackURL: URL {
        URL(string: fallbackSupabaseURL) ?? URL(fileURLWithPath: "/")
    }

    private static func infoPlistValue(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let urlString: String
    private let anonKey: String

    let client: SupabaseClient

    // Public read-only accessors so other parts (like signed upload helper) can use them.
    var projectURL: URL { URL(string: urlString) ?? Self.safeFallbackURL }
    var publicAnonKey: String { anonKey }

    private init() {
        let configuredURLString = SupabaseManager.infoPlistValue(for: "SUPABASE_URL")
        let configuredAnonKey = SupabaseManager.infoPlistValue(for: "SUPABASE_ANON_KEY")

        if configuredURLString == nil || configuredAnonKey == nil {
            debugLog("[SupabaseManager] Missing SUPABASE_URL and/or SUPABASE_ANON_KEY in Info.plist. Using safe fallback values.")
        }

        if let configuredURLString, URL(string: configuredURLString) != nil {
            self.urlString = configuredURLString
        } else {
            self.urlString = SupabaseManager.fallbackSupabaseURL
        }
        self.anonKey = configuredAnonKey ?? ""

        let url = URL(string: self.urlString) ?? SupabaseManager.safeFallbackURL

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

    /// Notification posted when the session has expired and cannot be refreshed.
    /// Observers (e.g., SceneDelegate) should present the login screen.
    static let sessionExpiredNotification = Notification.Name("SupabaseSessionExpired")

    /// Synchronous read — returns the cached user ID if a session is already loaded.
    /// Use this in hot paths (e.g. cell configuration) to avoid unnecessary async hops.
    /// Falls back to `nil` if no session is cached yet.
    func currentUserIdSync() -> String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }

    /// Async version — triggers a network refresh of the session if needed.
    /// Prefer `currentUserIdSync()` when a session is already known to exist.
    func currentUserId() async -> String? {
        do {
            let session = try await client.auth.session
            return session.user.id.uuidString.lowercased()
        } catch {
            return nil
        }
    }

    /// Verifies the current session is valid and attempts a refresh if needed.
    /// Returns `true` if a valid session exists (or was successfully refreshed), `false` otherwise.
    /// On irrecoverable failure, posts `sessionExpiredNotification` so the UI can redirect to login.
    @discardableResult
    func ensureValidSession() async -> Bool {
        do {
            // Attempt to get the session — the SDK will auto-refresh if configured
            let session = try await client.auth.session
            // Verify we have a valid user
            guard !session.user.id.uuidString.isEmpty else {
                throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid user in session"])
            }
            return true
        } catch {
            // First failure — try an explicit refresh
            do {
                debugLog("[SupabaseManager] Session fetch failed, attempting explicit refresh...")
                _ = try await client.auth.refreshSession()
                debugLog("[SupabaseManager] Session refreshed successfully")
                return true
            } catch {
                debugLog("[SupabaseManager] Session refresh failed: \(error)")
                // Post notification so UI layer can handle (e.g. present login)
                await MainActor.run {
                    NotificationCenter.default.post(name: Self.sessionExpiredNotification, object: nil)
                }
                return false
            }
        }
    }

    func signOut() async throws {
        defer {
            AuthSessionStateStore.clear()
            DeviceSessionManager.clearLocalToken()
            CommunitySafetyService.shared.clearLocalState()
            PreloadManager.shared.reset()
            DistanceService.shared.clearAllDistanceCaches()
        }
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
            debugLog("createSignedUrl error: \(error)")
            return nil
        }
    }
}
