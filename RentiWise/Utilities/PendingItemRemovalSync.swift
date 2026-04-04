import Foundation
import Supabase
import PostgREST

actor PendingItemRemovalSync {
    static let shared = PendingItemRemovalSync()

    private var isSyncing = false

    private struct ItemStateRow: Decodable {
        let owner_id: String
        let is_active: Bool?
    }

    func syncIfNeeded() async {
        guard !isSyncing else { return }

        let pendingItemIDs = LocalItemVisibilityStore.pendingItemIDs()
        guard !pendingItemIDs.isEmpty else { return }

        guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var didChangeItems = false

        for itemId in pendingItemIDs {
            do {
                let response = try await SupabaseManager.shared.client
                    .from("items")
                    .select("owner_id,is_active")
                    .eq("id", value: itemId)
                    .limit(1)
                    .execute()

                let rows = try JSONDecoder().decode([ItemStateRow].self, from: response.data)

                guard let row = rows.first else {
                    LocalItemVisibilityStore.remove(itemId)
                    continue
                }

                guard row.owner_id.lowercased() == currentUserId.lowercased() else {
                    LocalItemVisibilityStore.remove(itemId)
                    continue
                }

                if row.is_active == false {
                    LocalItemVisibilityStore.remove(itemId)
                    continue
                }

                try await SupabaseManager.shared.client
                    .from("items")
                    .update(["is_active": false])
                    .eq("id", value: itemId)
                    .eq("owner_id", value: currentUserId)
                    .execute()

                LocalItemVisibilityStore.remove(itemId)
                didChangeItems = true
            } catch {
                debugLog("[PendingItemRemovalSync] Failed to sync item \(itemId): \(error)")
            }
        }

        if didChangeItems {
            await MainActor.run {
                NotificationCenter.default.post(name: Notification.Name("itemsShouldRefresh"), object: nil)
            }
        }
    }
}
