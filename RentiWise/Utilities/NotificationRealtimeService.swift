import Foundation
import Supabase

final class NotificationRealtimeService {
    static let shared = NotificationRealtimeService()

    private var realtimeChannel: RealtimeChannelV2?
    private var listeningTask: Task<Void, Never>?
    private var subscribedUserId: String?

    private init() {}

    func start() {
        Task { await refreshSubscription() }
    }

    func refresh() async {
        await refreshSubscription(force: true)
    }

    private func refreshSubscription(force: Bool = false) async {
        let currentUserId = await SupabaseManager.shared.currentUserId()

        guard let currentUserId else {
            await unsubscribe()
            return
        }

        if !force, subscribedUserId == currentUserId, realtimeChannel != nil {
            return
        }

        await unsubscribe()

        let channel = SupabaseManager.shared.client.realtimeV2.channel("notifications-\(currentUserId)")
        let insertStream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: "user_id=eq.\(currentUserId)"
        )

        listeningTask = Task { [weak self] in
            guard let self else { return }
            for await insert in insertStream {
                do {
                    let row = try insert.decodeRecord(as: LiveNotificationRow.self, decoder: JSONDecoder())
                    await self.handleInsert(row)
                } catch {
                    debugLog("[Notifications] Realtime decode failed: \(error.localizedDescription)")
                }
            }
        }

        do {
            try await channel.subscribeWithError()
            subscribedUserId = currentUserId
            realtimeChannel = channel
        } catch {
            debugLog("[Notifications] Realtime subscribe failed: \(error.localizedDescription)")
            listeningTask?.cancel()
            listeningTask = nil
        }
    }

    private func handleInsert(_ row: LiveNotificationRow) async {
        NotificationCenter.default.post(name: .notificationsDidUpdate, object: nil)
        NotificationService.shared.notifyImmediately(
            identifier: "live_\(row.id)",
            title: row.title,
            body: row.message,
            userInfo: [
                "notification_id": row.id,
                "notification_type": row.type,
                "request_id": row.request_id ?? ""
            ]
        )
    }

    private func unsubscribe() async {
        listeningTask?.cancel()
        listeningTask = nil
        subscribedUserId = nil

        if let realtimeChannel {
            await realtimeChannel.unsubscribe()
            self.realtimeChannel = nil
        }
    }
}

private struct LiveNotificationRow: Decodable {
    let id: String
    let type: String
    let title: String
    let message: String
    let request_id: String?
}
