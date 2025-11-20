//
//  ProfileService.swift
//  RentiWise
//
//  Created by admin99 on 18/11/25.
//

import Foundation
import Supabase

protocol ProfileServicing {
    func fetchCurrentUserProfile() async throws -> UserProfile
}

final class ProfileService: ProfileServicing {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchCurrentUserProfile() async throws -> UserProfile {
        // 1) Get current auth session user (non-optional Session in this SDK)
        let session = try await client.auth.session
        let authUser = session.user // User is non-optional in this SDK

        // 2) Try to fetch from "users" table
        do {
            let response = try await client
                .from("users")
                .select()
                .eq("id", value: authUser.id.uuidString) // unlabeled eq; UUID -> String
                .single()
                .execute()

            let row = try JSONDecoder().decode(DBUserRow.self, from: response.data)

            // Build a UserProfile preferring DB values, falling back to auth email
            let email = row.email ?? authUser.email ?? ""
            let fullName = row.full_name ?? ""
            let phone = row.phone ?? ""

            return UserProfile(id: row.id, fullName: fullName, email: email, phone: phone)
        } catch {
            // If DB row not found, at least return auth email so UI shows something
            let email = authUser.email ?? ""
            return UserProfile(id: authUser.id.uuidString, fullName: "", email: email, phone: "")
        }
    }
}
