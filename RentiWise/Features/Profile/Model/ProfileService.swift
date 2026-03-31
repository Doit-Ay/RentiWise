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
    func saveCurrentUserProfile(_ input: ProfileSaveInput) async throws -> UserProfile
}

final class ProfileService: ProfileServicing {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchCurrentUserProfile() async throws -> UserProfile {
        let session = try await client.auth.session
        let authUser = session.user
        let userId = authUser.id.uuidString

        async let privateRowTask = fetchPrivateUserRow(userId: userId)
        async let publicRowTask = fetchPublicUserProfileRow(userId: userId)

        let privateRow = await privateRowTask
        let publicRow = await publicRowTask

        let email = privateRow?.email ?? authUser.email ?? ""
        let fullName = publicRow?.full_name ?? privateRow?.full_name ?? ""
        let phone = privateRow?.phone ?? ""
        let phoneVerified = privateRow?.is_phone_verified ?? false
        let kycStatus = privateRow?.kyc_status ?? "none"

        return UserProfile(
            id: userId,
            fullName: fullName,
            email: email,
            phone: phone,
            phoneVerified: phoneVerified,
            kycStatus: kycStatus,
            upiId: publicRow?.upi_id ?? "",
            collegeEmail: publicRow?.college_email ?? "",
            isCollegeVerified: publicRow?.is_college_verified ?? false,
            averageRating: publicRow?.average_rating ?? 0,
            totalRentalsAsBorrower: publicRow?.total_rentals_as_borrower ?? 0,
            borrowFreezeUntil: publicRow?.borrow_freeze_until
        )
    }

    func saveCurrentUserProfile(_ input: ProfileSaveInput) async throws -> UserProfile {
        let session = try await client.auth.session
        let authUser = session.user
        let userId = authUser.id.uuidString

        let fullName = input.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = input.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let upiId = Self.normalizedOrNil(input.upiId)
        let collegeEmail = Self.normalizedEmailOrNil(input.collegeEmail)
        let isCollegeVerified = Self.isEducationalEmail(collegeEmail ?? "")

        struct PrivateUserUpsert: Encodable {
            let id: String
            let email: String
            let full_name: String
            let phone: String
        }

        struct PublicUserProfileUpsert: Encodable {
            let id: String
            let full_name: String
            let upi_id: String?
            let college_email: String?
            let is_college_verified: Bool
        }

        _ = try await client
            .from("users")
            .upsert(
                PrivateUserUpsert(
                    id: userId,
                    email: authUser.email ?? "",
                    full_name: fullName,
                    phone: phone
                )
            )
            .execute()

        _ = try await client
            .from("user_profiles")
            .upsert(
                PublicUserProfileUpsert(
                    id: userId,
                    full_name: fullName,
                    upi_id: upiId,
                    college_email: collegeEmail,
                    is_college_verified: isCollegeVerified
                )
            )
            .execute()

        return try await fetchCurrentUserProfile()
    }

    private func fetchPrivateUserRow(userId: String) async -> DBUserRow? {
        do {
            let response = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()

            return try JSONDecoder().decode(DBUserRow.self, from: response.data)
        } catch {
            return nil
        }
    }

    private func fetchPublicUserProfileRow(userId: String) async -> DBUserProfileRow? {
        do {
            let response = try await client
                .from("user_profiles")
                .select("id,full_name,upi_id,college_email,is_college_verified,average_rating,total_rentals_as_borrower,borrow_freeze_until")
                .eq("id", value: userId)
                .single()
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DBUserProfileRow.self, from: response.data)
        } catch {
            return nil
        }
    }

    static func isEducationalEmail(_ email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let domain = normalized.split(separator: "@").last.map(String.init), !domain.isEmpty else {
            return false
        }

        let suffixes = [".edu", ".edu.in", ".ac.in", ".ac.uk", ".edu.au"]
        if suffixes.contains(where: { domain.hasSuffix($0) }) {
            return true
        }

        return domain.contains(".edu.") || domain.contains(".ac.")
    }

    private static func normalizedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedEmailOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
