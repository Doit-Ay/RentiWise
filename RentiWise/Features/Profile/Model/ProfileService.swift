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
        async let publicCoreTask = fetchPublicUserProfileCoreRow(userId: userId)
        async let publicStatsTask = fetchPublicUserProfileStatsRow(userId: userId)

        let privateRow = await privateRowTask
        let publicCore = await publicCoreTask
        let publicStats = await publicStatsTask

        let email = privateRow?.email ?? authUser.email ?? ""
        let fullName = publicCore?.full_name ?? privateRow?.full_name ?? ""
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
            upiId: publicCore?.upi_id ?? privateRow?.upi_id ?? "",
            collegeEmail: publicCore?.college_email ?? privateRow?.college_email ?? "",
            isCollegeVerified: publicCore?.is_college_verified ?? privateRow?.is_college_verified ?? false,
            averageRating: publicStats?.average_rating ?? 0,
            totalRentalsAsBorrower: publicStats?.total_rentals_as_borrower ?? 0,
            borrowFreezeUntil: publicStats?.borrow_freeze_until
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

    private func fetchPublicUserProfileCoreRow(userId: String) async -> PublicUserProfileCoreRow? {
        do {
            let response = try await client
                .from("user_profiles")
                .select("id,full_name,upi_id,college_email,is_college_verified")
                .eq("id", value: userId)
                .single()
                .execute()

            return try JSONDecoder().decode(PublicUserProfileCoreRow.self, from: response.data)
        } catch {
            return nil
        }
    }

    private func fetchPublicUserProfileStatsRow(userId: String) async -> PublicUserProfileStatsRow? {
        do {
            let response = try await client
                .from("user_profiles")
                .select("average_rating,total_rentals_as_borrower,borrow_freeze_until")
                .eq("id", value: userId)
                .single()
                .execute()

            guard
                let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            else {
                return nil
            }

            let averageRating = object["average_rating"] as? Double
                ?? (object["average_rating"] as? NSNumber)?.doubleValue
            let totalRentals = object["total_rentals_as_borrower"] as? Int
                ?? (object["total_rentals_as_borrower"] as? NSNumber)?.intValue
            let freezeUntil = parseFlexibleISODate(object["borrow_freeze_until"])

            return PublicUserProfileStatsRow(
                average_rating: averageRating,
                total_rentals_as_borrower: totalRentals,
                borrow_freeze_until: freezeUntil
            )
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

    private func parseFlexibleISODate(_ value: Any?) -> Date? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }

        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractional.date(from: raw) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

private struct PublicUserProfileCoreRow: Decodable {
    let id: String
    let full_name: String?
    let upi_id: String?
    let college_email: String?
    let is_college_verified: Bool?
}

private struct PublicUserProfileStatsRow {
    let average_rating: Double?
    let total_rentals_as_borrower: Int?
    let borrow_freeze_until: Date?
}
