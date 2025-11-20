// StorageService.swift
import Foundation
import Supabase

struct StorageService {
    let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // Return a signed URL as String
    func signedURLString(bucket: String, path: String, expiresIn seconds: Int = 3600) async throws -> String {
        // createSignedURL returns a URL in this SDK version
        let url: URL = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: seconds)

        return url.absoluteString
    }

    // Return a signed URL as URL
    func signedURL(bucket: String, path: String, expiresIn seconds: Int = 3600) async throws -> URL {
        let url: URL = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: seconds)

        return url
    }
}
