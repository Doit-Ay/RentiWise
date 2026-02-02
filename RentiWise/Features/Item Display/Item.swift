// Item.swift
// RentiWise

import Foundation

struct Item: Decodable {
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
    let created_at: Date?
    let updated_at: Date?
    
    // Rating stats (computed from reviews table)
    let average_rating: Double?
    let review_count: Int?
    
    // Memberwise initializer for creating items with stats
    init(id: String, owner_id: String, title: String, description: String?, category: String?, 
         condition: String?, price_per_day: Double, deposit_amount: Double, images: [String],
         is_active: Bool, created_at: Date?, updated_at: Date?,
         average_rating: Double? = nil, review_count: Int? = nil) {
        self.id = id
        self.owner_id = owner_id
        self.title = title
        self.description = description
        self.category = category
        self.condition = condition
        self.price_per_day = price_per_day
        self.deposit_amount = deposit_amount
        self.images = images
        self.is_active = is_active
        self.created_at = created_at
        self.updated_at = updated_at
        self.average_rating = average_rating
        self.review_count = review_count
    }

    enum CodingKeys: String, CodingKey {
        case id
        case owner_id
        case title
        case description
        case category
        case condition
        case price_per_day
        case deposit_amount
        case images
        case is_active
        case created_at
        case updated_at
        case average_rating
        case review_count
    }
}
