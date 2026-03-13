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
                review_count: stats?.review_count
            )
        }

        return items
    }
    
    private func fetchRatingStats(for itemIds: [String]) async -> [String: ItemRatingStats] {
        print("📦 ItemsService: Fetching rating stats for \(itemIds.count) items")
        
        let result = await withTaskGroup(of: (String, ItemRatingStats?, Error?).self) { group in
            for itemId in itemIds {
                group.addTask {
                    do {
                        let stats = try await self.reviewService.fetchItemStats(itemId: itemId)
                        return (itemId, stats, nil)
                    } catch {
                        print("❌ ItemsService: Error fetching stats for \(itemId): \(error)")
                        return (itemId, nil, error)
                    }
                }
            }
            
            var statsMap: [String: ItemRatingStats] = [:]
            for await (itemId, stats, error) in group {
                if let error = error {
                    print("❌ ItemsService: Failed to get stats for \(itemId): \(error.localizedDescription)")
                }
                if let stats = stats {
                    print("✅ ItemsService: Got stats for \(itemId) - avg: \(stats.average_rating ?? 0), count: \(stats.review_count)")
                    statsMap[itemId] = stats
                }
            }
            print("📊 ItemsService: Total stats fetched: \(statsMap.count)/\(itemIds.count)")
            return statsMap
        }
        
        return result
    }
}
