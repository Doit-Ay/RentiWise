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
    }
}
