// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata

import Foundation
import Supabase

protocol SupportChatServicing {
    func createSupportTicket(subject: String, message: String) async throws -> SupportTicket
    func sendSupportMessage(ticketId: String, text: String, isFromSupport: Bool) async throws -> SupportMessage
    func closeTicket(ticketId: String, status: String) async throws
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
    }

    func createSupportTicket(subject: String, message: String) async throws -> SupportTicket {
        let session = try await client.auth.session
        let userId = session.user.id.uuidString

        let payload = CreateTicketPayload(
            user_id: userId,
            subject: subject,
            priority: "low",
            status: "open"
        )

        let response = try await client
            .from("support_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let ticket = try decoder.decode(SupportTicket.self, from: response.data)
        
        // Save the first user message
        _ = try await sendSupportMessage(ticketId: ticket.id, text: message, isFromSupport: false)
        
        return ticket
    }

    // MARK: - Messages
    private struct CreateMessagePayload: Encodable {
        let ticket_id: String
        let sender_id: String
        let text: String
        let is_from_support: Bool
    }

    func sendSupportMessage(ticketId: String, text: String, isFromSupport: Bool = false) async throws -> SupportMessage {
        let session = try await client.auth.session
        let userId = session.user.id.uuidString

        let payload = CreateMessagePayload(
            ticket_id: ticketId,
            sender_id: isFromSupport ? "support" : userId,
            text: text,
            is_from_support: isFromSupport
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

    // MARK: - Close Ticket

    private struct UpdateStatusPayload: Encodable {
        let status: String
    }

    private struct UpdateStatusResolvedPayload: Encodable {
        let status: String
        let resolved_at: String
    }

    func closeTicket(ticketId: String, status: String) async throws {
        if status == "resolved" {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let resolvedAt = formatter.string(from: Date())
            let payload = UpdateStatusResolvedPayload(status: status, resolved_at: resolvedAt)
            _ = try await client
                .from("support_tickets")
                .update(payload)
                .eq("id", value: ticketId)
                .execute()
        } else {
            let payload = UpdateStatusPayload(status: status)
            _ = try await client
                .from("support_tickets")
                .update(payload)
                .eq("id", value: ticketId)
                .execute()
        }
        debugLog("[SupportChatService] Ticket \(ticketId) status updated to: \(status)")
    }
}
