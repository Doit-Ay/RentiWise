//
//  ReviewService.swift
//  RentiWise
//
//  Created by admin99 on 03/02/26.
//

import Foundation
import Supabase

protocol ReviewServicing {
    func fetchItemStats(itemId: String) async throws -> ItemRatingStats
    func fetchItemStatsBatch(itemIds: [String]) async throws -> [String: ItemRatingStats]
    func fetchReviews(itemId: String) async throws -> [Review]
}

final class ReviewService: ReviewServicing {
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }
    
    /// Fetch aggregated rating stats for a specific item
    func fetchItemStats(itemId: String) async throws -> ItemRatingStats {
        debugLog("🔍 ReviewService: Fetching stats for item: \(itemId)")
        
        // Query reviews for this item and compute stats
        let response = try await client
            .from("reviews")
            .select("rating")
            .eq("item_id", value: itemId)
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        
        struct ReviewRating: Decodable {
            let rating: Int
        }
        
        let ratings = try decoder.decode([ReviewRating].self, from: data)
        debugLog("📊 ReviewService: Found \(ratings.count) reviews for item \(itemId)")
        
        if ratings.isEmpty {
            return ItemRatingStats(average_rating: nil, review_count: 0)
        }
        
        let sum = ratings.reduce(0) { $0 + $1.rating }
        let average = Double(sum) / Double(ratings.count)
        
        debugLog("⭐️ ReviewService: Average rating: \(average), Count: \(ratings.count)")
        
        return ItemRatingStats(
            average_rating: average,
            review_count: ratings.count
        )
    }
    
    /// Batch fetch rating stats for multiple items in a single query.
    /// Replaces N individual queries with 1, dramatically reducing load time.
    func fetchItemStatsBatch(itemIds: [String]) async throws -> [String: ItemRatingStats] {
        guard !itemIds.isEmpty else { return [:] }
        
        struct ReviewRow: Decodable {
            let item_id: String
            let rating: Int
        }
        
        let response = try await client
            .from("reviews")
            .select("item_id,rating")
            .in("item_id", values: itemIds)
            .execute()
        
        let rows = try JSONDecoder().decode([ReviewRow].self, from: response.data)
        
        // Group by item_id and compute stats
        var grouped: [String: [Int]] = [:]
        for row in rows {
            grouped[row.item_id, default: []].append(row.rating)
        }
        
        var result: [String: ItemRatingStats] = [:]
        for itemId in itemIds {
            if let ratings = grouped[itemId], !ratings.isEmpty {
                let sum = ratings.reduce(0, +)
                let average = Double(sum) / Double(ratings.count)
                result[itemId] = ItemRatingStats(average_rating: average, review_count: ratings.count)
            } else {
                result[itemId] = ItemRatingStats(average_rating: nil, review_count: 0)
            }
        }
        return result
    }
    
    /// Fetch all reviews for a specific item
    func fetchReviews(itemId: String) async throws -> [Review] {
        let response = try await client
            .from("reviews")
            .select()
            .eq("item_id", value: itemId)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([Review].self, from: data)
    }
}
