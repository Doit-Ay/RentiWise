//
//  SignInModels.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import Foundation

struct SignInCredentials {
    let email: String
    let password: String
}

struct SignInDBUserRow: Encodable {
    let id: String
    let email: String
    let full_name: String
    let phone: String
}

// Minimal payload for first-time profile creation to avoid overwriting existing fields
struct MinimalUserInsert: Encodable {
    let id: String
    let email: String
}

