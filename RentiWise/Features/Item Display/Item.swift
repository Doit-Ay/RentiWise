// Item.swift
// RentiWise

import Foundation

struct Item: Decodable, Sendable {
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
    
    // Rating stats (computed from reviews table)
    let average_rating: Double?
    let review_count: Int?
    
    // Memberwise initializer for creating items with stats
    init(id: String, owner_id: String, title: String, description: String?, category: String?, 
         condition: String?, price_per_day: Double, deposit_amount: Double, images: [String],
         is_active: Bool, latitude: Double? = nil, longitude: Double? = nil,
         location_address: String? = nil, created_at: Date?, updated_at: Date?,
         average_rating: Double? = nil, review_count: Int? = nil, declared_value: Int? = nil, boosted_until: Date? = nil) {
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
        self.latitude = latitude
        self.longitude = longitude
        self.location_address = location_address
        self.created_at = created_at
        self.updated_at = updated_at
        self.declared_value = declared_value
        self.boosted_until = boosted_until
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
        case latitude
        case longitude
        case location_address
        case created_at
        case updated_at
        case average_rating
        case review_count
        case declared_value
        case boosted_until
    }

    var hasActiveBoost: Bool {
        guard let boostedUntil = boosted_until else { return false }
        return boostedUntil > Date()
    }
}

enum LocalItemVisibilityStore {
    private static let hiddenItemIDsKey = "RW.hidden_item_ids"

    static func pendingItemIDs() -> [String] {
        Array(normalizedHiddenIDs())
    }

    static func hide(_ itemId: String) {
        var hidden = normalizedHiddenIDs()
        hidden.insert(normalize(itemId))
        UserDefaults.standard.set(Array(hidden), forKey: hiddenItemIDsKey)
    }

    static func remove(_ itemId: String) {
        var hidden = normalizedHiddenIDs()
        hidden.remove(normalize(itemId))
        UserDefaults.standard.set(Array(hidden), forKey: hiddenItemIDsKey)
    }

    private static func normalizedHiddenIDs() -> Set<String> {
        let raw = UserDefaults.standard.stringArray(forKey: hiddenItemIDsKey) ?? []
        return Set(raw.map(normalize))
    }

    private static func normalize(_ itemId: String) -> String {
        itemId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
