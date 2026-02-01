// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata

//
//  ChatService.swift
//  RentiWise
//
import Foundation
import Supabase

final class ChatServiceV2 {
  
   static let shared = ChatServiceV2()
  
   private let client: SupabaseClient
   private let decoder: JSONDecoder
   private let iso8601WithFS: ISO8601DateFormatter = {
       let f = ISO8601DateFormatter()
       f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
       return f
   }()
  
   private init() {
       self.client = SupabaseManager.shared.client
       self.decoder = JSONDecoder()
       self.decoder.dateDecodingStrategy = .iso8601
   }
  
   // MARK: - Conversations

   private struct NewConversationPayload: Encodable {
       let lender_id: String
       let borrower_id: String
       let item_id: String?
   }

   private struct ItemOwnerDTO: Decodable { let owner_id: String }
  
   func fetchConversations() async throws -> [ChatConversation] {
       guard let userId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }
      
       let response = try await client
           .from("chat_conversations")
           .select()
           .or("lender_id.eq.\(userId),borrower_id.eq.\(userId)")
           .order("last_message_at", ascending: false)
           .execute()
      
       return try decoder.decode([ChatConversation].self, from: response.data)
   }

   // Enforce item-based conversations so lender/borrower roles are always correct.
   // If itemId is missing, we fail instead of creating an ambiguous row.
    func getOrCreateConversation(withUserId otherId: String, itemId: String?) async throws -> ChatConversation {
        guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
            throw ChatServiceError.notAuthenticated
        }

        // If we have an item, keep strict item-based conversation (recommended)
        if let itemId, !itemId.isEmpty {
            // Resolve owner for the item; owner is the lender.
            let itemResp = try await client
                .from("items")
                .select("owner_id")
                .eq("id", value: itemId)
                .single()
                .execute()
            let owner = try decoder.decode(ItemOwnerDTO.self, from: itemResp.data).owner_id

            let lenderId = owner
            let borrowerId = (currentUserId == owner) ? otherId : currentUserId

            print("[GetOrCreate] strict item flow currentUser=\(currentUserId) owner=\(owner) other=\(otherId) lender=\(lenderId) borrower=\(borrowerId) itemId=\(itemId)")

            if let existing = try? await fetchSingleConversation(lenderId: lenderId, borrowerId: borrowerId, itemId: itemId) {
                return existing
            }

            let payload = NewConversationPayload(lender_id: lenderId, borrower_id: borrowerId, item_id: itemId)
            let createResponse = try await client
                .from("chat_conversations")
                .insert(payload)
                .select()
                .single()
                .execute()
            return try decoder.decode(ChatConversation.self, from: createResponse.data)
        }

        // Fallback (legacy) when itemId is missing: try to find an existing conversation regardless of role order for null item_id
        print("[GetOrCreate] fallback (no item) currentUser=\(currentUserId) other=\(otherId)")
        do {
            let resp = try await client
                .from("chat_conversations")
                .select()
                .or("and(lender_id.eq.\(currentUserId),borrower_id.eq.\(otherId)),and(lender_id.eq.\(otherId),borrower_id.eq.\(currentUserId))")
                .filter("item_id", operator: "is", value: "null")
                .limit(1)
                .execute()
            let rows = try decoder.decode([ChatConversation].self, from: resp.data)
            if let found = rows.first { return found }
        } catch {
            // ignore and proceed to create
        }

        // Create a new conversation with a consistent role assignment: pick the lexicographically smaller id as lender for stability
        let lenderId = min(currentUserId, otherId)
        let borrowerId = (lenderId == currentUserId) ? otherId : currentUserId
        print("[GetOrCreate] creating fallback conversation lender=\(lenderId) borrower=\(borrowerId)")
        let payload = NewConversationPayload(lender_id: lenderId, borrower_id: borrowerId, item_id: nil)
        let createResponse = try await client
            .from("chat_conversations")
            .insert(payload)
            .select()
            .single()
            .execute()
        return try decoder.decode(ChatConversation.self, from: createResponse.data)
    }

   private func fetchSingleConversation(lenderId: String, borrowerId: String, itemId: String?) async throws -> ChatConversation {
       var query = client
           .from("chat_conversations")
           .select()
           .eq("lender_id", value: lenderId)
           .eq("borrower_id", value: borrowerId)

       if let itemId, !itemId.isEmpty {
           query = query.eq("item_id", value: itemId)
       } else {
           // Not used in enforced item-chat flow; keep null filter for safety.
           query = query.filter("item_id", operator: "is", value: "null")
       }

       let resp = try await query.single().execute()
       return try decoder.decode(ChatConversation.self, from: resp.data)
   }
  
   // MARK: - Messages

   private struct NewMessagePayload: Encodable {
       let conversation_id: String
       let sender_id: String
       let text: String
       let is_read: Bool
   }

   private struct ConversationUpdatePayload: Encodable {
       let last_message: String
       let last_message_at: String
   }
  
   func fetchMessages(conversationId: String, limit: Int = 100) async throws -> [ChatMessage] {
       let response = try await client
           .from("chat_messages")
           .select()
           .eq("conversation_id", value: conversationId)
           .order("created_at", ascending: true)
           .limit(limit)
           .execute()
      
       return try decoder.decode([ChatMessage].self, from: response.data)
   }
  
   func sendMessage(conversationId: String, text: String) async throws -> ChatMessage {
       guard let userId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }
      
       let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
       guard !trimmedText.isEmpty else {
           throw ChatServiceError.emptyMessage
       }
      
       let message = NewMessagePayload(conversation_id: conversationId, sender_id: userId, text: trimmedText, is_read: false)
      
       let response = try await client
           .from("chat_messages")
           .insert(message)
           .select()
           .single()
           .execute()
      
       // Update conversation summary for ordering in list
       let now = iso8601WithFS.string(from: Date())
       try? await client
           .from("chat_conversations")
           .update(ConversationUpdatePayload(last_message: trimmedText, last_message_at: now))
           .eq("id", value: conversationId)
           .execute()
      
       return try decoder.decode(ChatMessage.self, from: response.data)
   }
  
   func markMessagesAsRead(conversationId: String) async throws {
       guard let userId = await SupabaseManager.shared.currentUserId() else { return }
       try await client
           .from("chat_messages")
           .update(["is_read": true])
           .eq("conversation_id", value: conversationId)
           .neq("sender_id", value: userId)
           .eq("is_read", value: false)
           .execute()
   }
  
   // MARK: - Support tickets (unchanged)

   private struct NewTicketPayload: Encodable {
       let user_id: String
       let subject: String
       let status: String
       let priority: String
   }

   private struct NewSupportMessagePayload: Encodable {
       let ticket_id: String
       let sender_id: String
       let text: String
       let is_from_support: Bool
   }
  
   func createSupportTicket(subject: String, initialMessage: String) async throws -> SupportTicket {
       guard let userId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }
      
       let ticket = NewTicketPayload(user_id: userId, subject: subject, status: "open", priority: "medium")
       let response = try await client
           .from("support_tickets")
           .insert(ticket)
           .select()
           .single()
           .execute()
       let createdTicket = try decoder.decode(SupportTicket.self, from: response.data)
      
       let message = NewSupportMessagePayload(ticket_id: createdTicket.id, sender_id: userId, text: initialMessage, is_from_support: false)
       try await client
           .from("support_messages")
           .insert(message)
           .execute()
      
       return createdTicket
   }
  
   func sendSupportMessage(ticketId: String, text: String) async throws -> SupportMessage {
       guard let userId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }
      
       let message = NewSupportMessagePayload(ticket_id: ticketId, sender_id: userId, text: text, is_from_support: false)
       let response = try await client
           .from("support_messages")
           .insert(message)
           .select()
           .single()
           .execute()
       return try decoder.decode(SupportMessage.self, from: response.data)
   }
  
   func fetchParticipantInfo(userId: String) async throws -> ParticipantInfo {
       let response = try await client
           .from("user_profiles")
           .select("id,full_name,profile_photo_url")
           .eq("id", value: userId)
           .single()
           .execute()
       return try decoder.decode(ParticipantInfo.self, from: response.data)
   }
}

enum ChatServiceError: Error, LocalizedError {
   case notAuthenticated
   case emptyMessage
   case conversationNotFound
   case messageSendFailed
  
   var errorDescription: String? {
       switch self {
       case .notAuthenticated: return "You must be logged in to chat."
       case .emptyMessage: return "Message cannot be empty."
       case .conversationNotFound: return "Conversation not found."
       case .messageSendFailed: return "Failed to send message."
       }
   }
}

