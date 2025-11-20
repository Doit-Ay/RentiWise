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
}

// Raw DB row from Supabase "users" table
struct DBUserRow: Decodable {
    let id: String
    let email: String?
    let full_name: String?
    let phone: String?
    let profile_photo_url: String?
}

