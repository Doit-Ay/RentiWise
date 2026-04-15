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
       // Supabase returns timestamps with fractional seconds (e.g. .123456)
       // which the built-in .iso8601 strategy does NOT handle.
       // Use a custom strategy that tries fractional-second format first.
       self.decoder.dateDecodingStrategy = .custom { decoder in
           let container = try decoder.singleValueContainer()
           let dateString = try container.decode(String.self)
           // Try with fractional seconds first (Supabase default)
           if let date = self.iso8601WithFS.date(from: dateString) {
               return date
           }
           // Fallback: standard ISO8601 without fractional seconds
           let iso = ISO8601DateFormatter()
           if let date = iso.date(from: dateString) {
               return date
           }
           throw DecodingError.dataCorruptedError(
               in: container,
               debugDescription: "Cannot decode date: \(dateString)"
           )
       }
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
   // If itemId is missing, we keep a generic 1:1 legacy flow but still prevent self-chat.
   func getOrCreateConversation(withUserId otherId: String, itemId: String?) async throws -> ChatConversation {
       guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
           throw ChatServiceError.notAuthenticated
       }
       
       debugLog("[ChatService] Starting getOrCreateConversation flow")

       // Prevent obvious self-chat regardless of path
       if currentUserId == otherId {
           debugLog("[ChatService] Refused self-chat attempt")
           throw ChatServiceError.conversationNotFound // or a dedicated selfChat error if you prefer
       }

       // ITEM-BOUND CONVERSATION (recommended)
       if let itemId, !itemId.isEmpty {
           debugLog("[ChatService] Resolving item owner for item-bound chat")
           
           // 1) Resolve item owner (this is the lender, always)
           let itemResp = try await client
               .from("items")
               .select("owner_id")
               .eq("id", value: itemId)
               .single()
               .execute()
           let owner = try decoder.decode(ItemOwnerDTO.self, from: itemResp.data).owner_id
           let lenderId = owner
           
           debugLog("[ChatService] Resolved lender for item-bound chat")

           // 2) Determine borrower:
           // - If current user is the owner, then otherId must be the borrower (and must not equal owner).
           // - Otherwise, current user is the borrower.
           let borrowerId: String
           if currentUserId.lowercased() == owner.lowercased() {
               debugLog("[ChatService] Owner initiated item-bound chat")
               // Owner initiating chat: otherId must be the borrower id
               guard otherId.lowercased() != owner.lowercased() else {
                   debugLog("[ChatService] Refused owner self-chat attempt")
                   throw ChatServiceError.conversationNotFound // refuse to create self-chat
               }
               borrowerId = otherId
               debugLog("[ChatService] Borrower resolved from other participant")
           } else {
               debugLog("[ChatService] Borrower initiated item-bound chat")
               // Borrower initiating chat: they are the borrower
               borrowerId = currentUserId
               debugLog("[ChatService] Borrower resolved from current user")
               // Optional sanity: ensure otherId matches the owner we resolved
               // If UI passed a different otherId, we still keep lender = owner.
           }

           // Final guard (defensive)
           guard lenderId != borrowerId else {
               debugLog("[ChatService] Refused invalid lender/borrower pairing")
               throw ChatServiceError.conversationNotFound
           }

           // 3) Try existing conversation first (unique per lender/borrower/item)
           debugLog("[ChatService] Checking for existing conversation")
           if let existing = try? await fetchSingleConversation(lenderId: lenderId, borrowerId: borrowerId, itemId: itemId) {
               // Validate existing conversation doesn't have self-chat (corrupted data)
               if existing.lender_id == existing.borrower_id {
                   debugLog("[ChatService] Ignoring corrupted self-chat conversation")
                   // Don't return the bad conversation; fall through to create a new one
               } else {
                   debugLog("[ChatService] Reusing existing conversation")
                   return existing
               }
           }

           // 4) Create new - but handle race condition where conversation was just created
           debugLog("[ChatService] Creating conversation")
           let payload = NewConversationPayload(lender_id: lenderId, borrower_id: borrowerId, item_id: itemId)
           
           do {
               let createResponse = try await client
                   .from("chat_conversations")
                   .insert(payload)
                   .select()
                   .single()
                   .execute()
               let newConvo = try decoder.decode(ChatConversation.self, from: createResponse.data)
               debugLog("[ChatService] Created conversation successfully")
               return newConvo
           } catch {
               // If creation failed (likely duplicate key), try to fetch the existing one again
               debugLog("[ChatService] Conversation create raced with another request; retrying fetch")
               
               if let existing = try? await fetchSingleConversation(lenderId: lenderId, borrowerId: borrowerId, itemId: itemId) {
                   debugLog("[ChatService] Recovered existing conversation after retry")
                   return existing
               }
               
               // If we still can't find it, throw the original error
               throw error
           }
       }

       // LEGACY FALLBACK (no item): generic 1:1 chat with stable role assignment and self-chat prevention
       // Keep a consistent ordering to avoid duplicates; still prevent self-chat.
       let lenderId = min(currentUserId, otherId)
       let borrowerId = (lenderId == currentUserId) ? otherId : currentUserId

       guard lenderId != borrowerId else {
           throw ChatServiceError.conversationNotFound
       }

       // Try to find an existing conversation (item_id IS NULL) regardless of role order
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

       // Create a new generic conversation
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
       try SafetyContentPolicy.validateChatMessage(trimmedText)
       try await ChatMessageRateLimiter.shared.registerSend(for: conversationId)
       
       let message = NewMessagePayload(conversation_id: conversationId, sender_id: userId, text: trimmedText, is_read: false)
      
       let response = try await client
           .from("chat_messages")
           .insert(message)
           .select()
           .single()
           .execute()
      
       // Update conversation summary for ordering in list
       let now = iso8601WithFS.string(from: Date())
       _ = try? await client
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
