// ItemsService.swift
// RentiWise

import Foundation
import Supabase

protocol ItemsServicing {
    func fetchItems(category: String) async throws -> [Item]
}

final class ItemsService: ItemsServicing {
    private let client: SupabaseClient
    private let reviewService: ReviewServicing

    init(client: SupabaseClient = SupabaseManager.shared.client,
         reviewService: ReviewServicing = ReviewService()) {
        self.client = client
        self.reviewService = reviewService
    }

    func fetchItems(category: String) async throws -> [Item] {
        // Build query with server-side filtering
        var query = client
            .from("items")
            .select() // all columns
            .eq("is_active", value: true)

        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            query = query.ilike("category", pattern: cat)
        }

        let response = try await query
            .order("created_at", ascending: false)
            .execute()

        let data = response.data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Decode into a mutable intermediate struct that we can enrich
        struct ItemDTO: Decodable {
            let id: String
            let owner_id: String
            let title: String
            let description: String?
            let category: String?
            let condition: String?
            let price_per_day: Double
            let deposit_amount: Double
            let images: [String]
            let is_active: Bool
            let latitude: Double?
            let longitude: Double?
            let location_address: String?
            let created_at: Date?
            let updated_at: Date?
            let declared_value: Int?
            let boosted_until: Date?
        }

        let itemDTOs = try decoder.decode([ItemDTO].self, from: data)

        // Fetch rating stats concurrently for all items
        let statsMap = await fetchRatingStats(for: itemDTOs.map { $0.id })
        
        // Map DTOs to Items with stats
        let items = itemDTOs.map { dto -> Item in
            let stats = statsMap[dto.id]
            return Item(
                id: dto.id,
                owner_id: dto.owner_id,
                title: dto.title,
                description: dto.description,
                category: dto.category,
                condition: dto.condition,
                price_per_day: dto.price_per_day,
                deposit_amount: dto.deposit_amount,
                images: dto.images,
                is_active: dto.is_active,
                latitude: dto.latitude,
                longitude: dto.longitude,
                location_address: dto.location_address,
                created_at: dto.created_at,
                updated_at: dto.updated_at,
                average_rating: stats?.average_rating,
                review_count: stats?.review_count,
                declared_value: dto.declared_value,
                boosted_until: dto.boosted_until
            )
        }

        return CommunitySafetyService.shared.visibleItems(from: items).sorted { lhs, rhs in
            if lhs.hasActiveBoost != rhs.hasActiveBoost {
                return lhs.hasActiveBoost && !rhs.hasActiveBoost
            }

            if lhs.hasActiveBoost, rhs.hasActiveBoost, lhs.boosted_until != rhs.boosted_until {
                return (lhs.boosted_until ?? .distantPast) > (rhs.boosted_until ?? .distantPast)
            }

            return (lhs.created_at ?? .distantPast) > (rhs.created_at ?? .distantPast)
        }
    }
    
    private func fetchRatingStats(for itemIds: [String]) async -> [String: ItemRatingStats] {
        debugLog("📦 ItemsService: Fetching rating stats for \(itemIds.count) items (batch)")
        
        do {
            let statsMap = try await reviewService.fetchItemStatsBatch(itemIds: itemIds)
            debugLog("📊 ItemsService: Batch stats fetched: \(statsMap.count)/\(itemIds.count)")
            return statsMap
        } catch {
            debugLog("❌ ItemsService: Batch stats error: \(error.localizedDescription)")
            // Fallback: return empty stats for all items
            return [:]
        }
    }
}
