//
//  ChatModels.swift
//  RentiWise
//
import Foundation

// MARK: - Message Model
struct ChatMessage: Codable, Identifiable, Equatable {
   let id: String
   let conversation_id: String
   let sender_id: String
   let text: String
   let created_at: Date
   let is_read: Bool
  
   func isCurrentUser(currentUserId: String) -> Bool {
       sender_id == currentUserId
   }
  
   var formattedTime: String {
       let formatter = DateFormatter()
       formatter.timeStyle = .short
       return formatter.string(from: created_at)
   }
}

// MARK: - Conversation Model
struct ChatConversation: Codable, Identifiable {
   let id: String
   let item_id: String?
   let lender_id: String
   let borrower_id: String
   let last_message: String?
   let last_message_at: Date?
   let created_at: Date
   let updated_at: Date?
  
   func otherParticipantId(currentUserId: String) -> String {
       currentUserId == lender_id ? borrower_id : lender_id
   }
}

// MARK: - Support Ticket Model
struct SupportTicket: Codable, Identifiable {
   let id: String
   let user_id: String
   let subject: String
   let status: TicketStatus
   let priority: TicketPriority
   let created_at: Date
   let updated_at: Date?
   let resolved_at: Date?
  
   enum TicketStatus: String, Codable {
       case open = "open"
       case inProgress = "in_progress"
       case resolved = "resolved"
       case closed = "closed"
   }
  
   enum TicketPriority: String, Codable {
       case low = "low"
       case medium = "medium"
       case high = "high"
       case urgent = "urgent"
   }
}

struct SupportMessage: Codable, Identifiable {
   let id: String
   let ticket_id: String
   let sender_id: String
   let text: String
   let is_from_support: Bool
   let created_at: Date
  
   var formattedTime: String {
       let formatter = DateFormatter()
       formatter.timeStyle = .short
       return formatter.string(from: created_at)
   }
}

struct ParticipantInfo: Codable {
   let id: String
   let full_name: String?
   let profile_photo_url: String?
  
   var displayName: String {
       full_name ?? "User"
   }
}
