//
//  Review.swift
//  RentiWise
//
//  Created by admin99 on 03/02/26.
//

import Foundation

struct Review: Decodable {
    let id: String
    let item_id: String
    let reviewer_id: String
    let rating: Int
    let review_text: String?
    let created_at: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case item_id
        case reviewer_id
        case rating
        case review_text
        case created_at
    }
}

struct ItemRatingStats: Decodable {
    let average_rating: Double?
    let review_count: Int
    
    enum CodingKeys: String, CodingKey {
        case average_rating
        case review_count
    }
}
