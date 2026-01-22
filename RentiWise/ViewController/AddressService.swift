import Foundation
import Supabase

protocol AddressServicing {
    func list() async throws -> [Address]
    func create(_ input: AddressInput) async throws -> Address
    func update(id: String, patch: AddressPatch) async throws -> Address
    func delete(id: String) async throws
    func setDefault(id: String) async throws
    func currentUserId() async throws -> String
}

final class AddressService: AddressServicing {
    private let client: SupabaseClient
    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func currentUserId() async throws -> String {
        let session = try await client.auth.session
        return session.user.id.uuidString
    }

    func list() async throws -> [Address] {
        let resp = try await client
            .from("addresses")
            .select()
            .order("is_default", ascending: false)
            .order("created_at", ascending: false)
            .execute()
        return try JSONDecoder().decode([Address].self, from: resp.data)
    }

    func create(_ input: AddressInput) async throws -> Address {
        let resp = try await client
            .from("addresses")
            .insert(input)
            .select()
            .single()
            .execute()
        let created = try JSONDecoder().decode(Address.self, from: resp.data)
        // If this is default, clear other defaults (RLS safe: scoped to user with server constraint)
        if created.is_default {
            try await clearOthersAndKeepDefault(defaultId: created.id)
        }
        return created
    }

    func update(id: String, patch: AddressPatch) async throws -> Address {
        let resp = try await client
            .from("addresses")
            .update(patch)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        let updated = try JSONDecoder().decode(Address.self, from: resp.data)
        if updated.is_default {
            try await clearOthersAndKeepDefault(defaultId: updated.id)
        }
        return updated
    }

    func delete(id: String) async throws {
        _ = try await client
            .from("addresses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func setDefault(id: String) async throws {
        // 1) Mark selected id is_default=true
        struct Patch: Encodable { let is_default: Bool }
        _ = try await client
            .from("addresses")
            .update(Patch(is_default: true))
            .eq("id", value: id)
            .execute()
        // 2) Clear others
        try await clearOthersAndKeepDefault(defaultId: id)
    }

    // Clear is_default=false for all other rows of the same user.
    private func clearOthersAndKeepDefault(defaultId: String) async throws {
        // Get the selected row to know the user_id
        let resp = try await client
            .from("addresses")
            .select("user_id")
            .eq("id", value: defaultId)
            .single()
            .execute()
        struct Row: Decodable { let user_id: String }
        let row = try JSONDecoder().decode(Row.self, from: resp.data)

        struct Patch: Encodable { let is_default: Bool }
        _ = try await client
            .from("addresses")
            .update(Patch(is_default: false))
            .eq("user_id", value: row.user_id)
            .neq("id", value: defaultId)
            .execute()
    }
}

