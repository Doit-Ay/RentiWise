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
  
   func getOrCreateConversation(withUserId otherId: String, itemId: String?) async throws -> ChatConversation {
       guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }

       let lenderId: String
       let borrowerId: String

       if let itemId = itemId, !itemId.isEmpty {
           let itemResp = try await client
               .from("items")
               .select("owner_id")
               .eq("id", value: itemId)
               .single()
               .execute()
           let owner = try decoder.decode(ItemOwnerDTO.self, from: itemResp.data).owner_id

           lenderId = owner
           borrowerId = (currentUserId == owner) ? otherId : currentUserId

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
       } else {
           lenderId = otherId
           borrowerId = currentUserId

           if let existing = try? await fetchSingleConversation(lenderId: lenderId, borrowerId: borrowerId, itemId: nil) {
               return existing
           }

           let payload = NewConversationPayload(lender_id: lenderId, borrower_id: borrowerId, item_id: nil)
           let createResponse = try await client
               .from("chat_conversations")
               .insert(payload)
               .select()
               .single()
               .execute()
           return try decoder.decode(ChatConversation.self, from: createResponse.data)
       }
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
           // Use filter(...) with IS NULL since PostgrestFilterBuilder has no `is_` member.
           // Option A (newer SDKs): query = query.filter("item_id", .is, "null")
           // Option B (string operator fallback compatible across versions):
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
  
   func fetchMessages(conversationId: String, limit: Int = 50) async throws -> [ChatMessage] {
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
           .execute()
   }
  
   // MARK: - Support Tickets

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

