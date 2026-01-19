// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata

import Foundation
import Supabase

protocol SupportChatServicing {
    func createSupportTicket(subject: String, message: String) async throws -> SupportTicket
    func sendSupportMessage(ticketId: String, text: String) async throws -> SupportMessage
}

final class SupportChatService: SupportChatServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Ticket
    private struct CreateTicketPayload: Encodable {
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
}
