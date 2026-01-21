//
//  RequestsModels.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import Foundation

// Shared models for lender requests with joined item
public struct RequestWithItem: Codable {
    public let id: String
    public let item_id: String
    public let owner_id: String
    public let borrower_id: String
    public let start_date: String   // "yyyy-MM-dd"
    public let end_date: String     // "yyyy-MM-dd"
    public let pickup_time: String?
    public var status: String
    public let created_at: String?

    public let items: ItemLite? // joined item
}

public struct ItemLite: Codable {
    public let id: String
    public let title: String
    public let images: [String]
    public let price_per_day: Double
    public let category: String?
    
    // Location coordinates for distance calculation
    public let latitude: Double?
    public let longitude: Double?
}
