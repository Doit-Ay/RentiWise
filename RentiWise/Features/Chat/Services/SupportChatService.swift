// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata

import Foundation
import Supabase

    func createSupportTicket(subject: String, message: String) async throws -> SupportTicket
    func sendSupportMessage(ticketId: String, text: String) async throws -> SupportMessage
    func subscribeToRealtime(ticketId: String, onMessage: @escaping (SupportMessage) -> Void) -> RealtimeChannelV2
}

final class SupportChatService: SupportChatServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }
    
    // ... (keep init and other methods, relying on file content being mostly same, just checking context)
    // Actually I should just target the subscribe method and protocol.
    
    // ...
    
    func subscribeToRealtime(ticketId: String, onMessage: @escaping (SupportMessage) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("public:support_messages:ticket_id=eq.\(ticketId)")
        
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "support_messages",
            filter: "ticket_id=eq.\(ticketId)"
        )
        
        Task {
            for await change in changeStream {
                switch change {
                case .insert(let record):
                    do {
                        let data = try JSONEncoder().encode(record.record) // Re-encode to decode properly
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let supportMessage = try decoder.decode(SupportMessage.self, from: data)
                        onMessage(supportMessage)
                    } catch {
                       print("Decoding error: \(error)")
                    }
                default: break
                }
            }
        }
        
        Task {
            await channel.subscribe()
        }
        
        return channel
    }
}
        let user_id: String
        let subject: String
        let priority: String
        let status: String
        let initial_message: String
    }

    func createSupportTicket(subject: String, message: String) async throws -> SupportTicket {
        let session = try await client.auth.session
        let userId = session.user.id.uuidString

        let payload = CreateTicketPayload(
            user_id: userId,
            subject: subject,
            priority: "low",
            status: "open",
            initial_message: message
        )

        let response = try await client
            .from("support_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SupportTicket.self, from: response.data)
    }

    // MARK: - Messages
    private struct CreateMessagePayload: Encodable {
        let ticket_id: String
        let sender_id: String
        let text: String
        let is_from_support: Bool
    }

    func sendSupportMessage(ticketId: String, text: String) async throws -> SupportMessage {
        let session = try await client.auth.session
        let userId = session.user.id.uuidString

        let payload = CreateMessagePayload(
            ticket_id: ticketId,
            sender_id: userId,
            text: text,
            is_from_support: false
        )

        let response = try await client
            .from("support_messages")
            .insert(payload)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SupportMessage.self, from: response.data)
    }

    func subscribeToRealtime(ticketId: String, onMessage: @escaping (SupportMessage) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("public:support_messages:ticket_id=eq.\(ticketId)")
        
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "support_messages",
            filter: "ticket_id=eq.\(ticketId)"
        )
        
        Task {
            for await change in changeStream {
                switch change {
                case .insert(let record):
                    do {
                        // The 'record' in AnyAction is usually [String: JSON] or similar. 
                        // We need to be careful with decoding. 
                        // If 'record' is the Encodable object, we can encode it back.
                        let data = try JSONEncoder().encode(record.record)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let supportMessage = try decoder.decode(SupportMessage.self, from: data)
                        onMessage(supportMessage)
                    } catch {
                        print("Realtime decoding error: \(error)")
                    }
                default: break
                }
            }
        }
        
        Task {
            await channel.subscribe()
        }
        
        return channel
    }
}
