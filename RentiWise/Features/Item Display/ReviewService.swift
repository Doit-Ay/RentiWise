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
