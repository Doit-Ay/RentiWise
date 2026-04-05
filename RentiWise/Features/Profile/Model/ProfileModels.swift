//
//  ProfileModels.swift
//  RentiWise
//
//  Created by admin99 on 18/11/25.
//

import Foundation

// What the view needs to display
struct UserProfile {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let phoneVerified: Bool
    let kycStatus: String
    let isLenderPro: Bool
    let upiId: String
    let collegeEmail: String
    let isCollegeVerified: Bool
    let averageRating: Double
    let totalRentalsAsBorrower: Int
    let borrowFreezeUntil: Date?
}

// Raw DB row from Supabase "users" table
struct DBUserRow: Decodable {
    let id: String
    let email: String?
    let full_name: String?
    let phone: String?
    let upi_id: String?
    let college_email: String?
    let is_college_verified: Bool?
    let profile_photo_url: String?
    let is_phone_verified: Bool?
    let kyc_status: String?
}

struct ProfileSaveInput {
    let fullName: String
    let phone: String
    let upiId: String
    let collegeEmail: String
}
