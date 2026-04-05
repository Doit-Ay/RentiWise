//
//  ItemModels.swift
//  RentiWise
//
//  Created by You on 18/11/25.
//

import Foundation

// Payload used to insert a new row into public.items
struct ItemInsertPayload: Encodable {
    let owner_id: String
    let title: String
    let description: String?
    let category: String?
    let condition: String?
    let price_per_day: Double
    let deposit_amount: Double
    let declared_value: Int
    let images: [String] // store Storage paths or URLs
    let is_active: Bool
    let latitude: Double?
    let longitude: Double?
    let location_address: String?
}

// Row shape returned from public.items
struct ItemRow: Decodable {
    let id: String
    let owner_id: String
    let title: String
    let description: String?
    let category: String?
    let condition: String?
    let price_per_day: Double
    let deposit_amount: Double
    let declared_value: Int?
    let images: [String]
    let is_active: Bool
    let latitude: Double?
    let longitude: Double?
    let location_address: String?
    let created_at: String
    let updated_at: String
}

// A draft object you pass between Add Item screens
struct AddItemDraft {
    var images: [Data] = []            // JPEG/PNG data for upload
    var title: String = ""
    var description: String = ""
    var category: String = ""
    var condition: String = ""
    var pricePerDay: Double = 0
    var depositAmount: Double = 0
    var declaredValue: Int = 0
    var isActive: Bool = true

    // Editing support
    var isEditing: Bool = false
    var existingItemId: String? = nil
    // The image paths already stored in DB for this item
    var existingImagePaths: [String] = []
}
