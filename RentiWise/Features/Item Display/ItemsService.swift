// ItemsService.swift
// RentiWise

import Foundation
import Supabase

protocol ItemsServicing {
    func fetchItems(category: String) async throws -> [Item]
}

final class ItemsService: ItemsServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchItems(category: String) async throws -> [Item] {
        // Fetch newest items and filter locally if needed (temporary fallback)
        let response = try await client
            .from("items")
            .select() // all columns
            .order("created_at", ascending: false)
            .execute()

        let data = response.data

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var items = try decoder.decode([Item].self, from: data)

        // Enforce is_active and optional category filter on the client side
        items = items.filter { $0.is_active }
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            items = items.filter { ($0.category ?? "").caseInsensitiveCompare(cat) == .orderedSame }
        }

        return items
    }
}
