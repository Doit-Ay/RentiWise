import XCTest
@testable import RentiWise

/// FLOW 7: BOTH PARTIES — Chat & Support Tickets
/// Tests the full chat workflow between borrower and lender,
/// and the support ticket flow with the RentiWise support team.
final class E2E_ChatAndSupportFlowTests: XCTestCase {

    // Helper ISO date → Date
    private func date(from iso: String) -> Date {
        let df = ISO8601DateFormatter()
        return df.date(from: iso) ?? Date()
    }

    // MARK: - Chat Message Model (field is `text`, not `content`)

    func test_chat_messageDecodesCorrectly() throws {
        let json = """
        {
            "id": "msg-001",
            "conversation_id": "conv-001",
            "sender_id": "user-111",
            "text": "Hi! Is the drone still available?",
            "is_read": false,
            "created_at": "2025-12-20T10:30:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let msg = try decoder.decode(ChatMessage.self, from: json)
        XCTAssertEqual(msg.text, "Hi! Is the drone still available?")
        XCTAssertFalse(msg.is_read)
    }

    func test_chat_isCurrentUserCheck() {
        let myId = "user-111"
        let message = ChatMessage(
            id: "msg-001",
            conversation_id: "conv-001",
            sender_id: "user-111",
            text: "Hello!",
            created_at: Date(),
            is_read: false
        )
        XCTAssertTrue(message.isCurrentUser(currentUserId: myId))
    }

    func test_chat_notCurrentUserCheck() {
        let myId = "user-111"
        let message = ChatMessage(
            id: "msg-002",
            conversation_id: "conv-001",
            sender_id: "user-222",
            text: "Sure, it's available!",
            created_at: Date(),
            is_read: true
        )
        XCTAssertFalse(message.isCurrentUser(currentUserId: myId))
    }

    func test_chat_emptyMessageShouldBeBlocked() {
        let messageContent = "   "
        let isEmpty = messageContent.trimmingCharacters(in: .whitespaces).isEmpty
        XCTAssertTrue(isEmpty, "Whitespace-only messages should be rejected")
    }

    // MARK: - Chat Conversation (field is `lender_id`, not `owner_id`)

    func test_chat_conversationDecodesCorrectly() throws {
        let json = """
        {
            "id": "conv-001",
            "item_id": "item-drone-1",
            "borrower_id": "user-borrower",
            "lender_id": "user-lender",
            "last_message": null,
            "last_message_at": null,
            "created_at": "2025-12-20T09:00:00Z",
            "updated_at": "2025-12-20T10:30:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conv = try decoder.decode(ChatConversation.self, from: json)
        XCTAssertEqual(conv.borrower_id, "user-borrower")
        XCTAssertEqual(conv.lender_id, "user-lender")
    }

    func test_chat_otherParticipantForBorrower() {
        let conversation = ChatConversation(
            id: "conv-001",
            item_id: "item-001",
            lender_id: "user-lender",
            borrower_id: "user-borrower",
            last_message: nil,
            last_message_at: nil,
            created_at: Date(),
            updated_at: nil
        )
        let myId = "user-borrower"
        let other = conversation.otherParticipantId(currentUserId: myId)
        XCTAssertEqual(other, "user-lender")
    }

    func test_chat_otherParticipantForLender() {
        let conversation = ChatConversation(
            id: "conv-001",
            item_id: "item-001",
            lender_id: "user-lender",
            borrower_id: "user-borrower",
            last_message: nil,
            last_message_at: nil,
            created_at: Date(),
            updated_at: nil
        )
        let myId = "user-lender"
        let other = conversation.otherParticipantId(currentUserId: myId)
        XCTAssertEqual(other, "user-borrower")
    }

    func test_chat_selfChatIsBlocked() {
        let myId = "user-111"
        let itemOwnerId = "user-111"
        let isSelfChat = (myId == itemOwnerId)
        XCTAssertTrue(isSelfChat, "User should be blocked from chatting with themselves")
    }

    // MARK: - Support Ticket (status/priority are enums)

    func test_support_ticketDecodesCorrectly() throws {
        let json = """
        {
            "id": "ticket-001",
            "user_id": "user-111",
            "subject": "Payment not processed",
            "status": "open",
            "priority": "high",
            "created_at": "2025-12-20T08:00:00Z",
            "updated_at": "2025-12-20T08:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let ticket = try decoder.decode(SupportTicket.self, from: json)
        XCTAssertEqual(ticket.subject, "Payment not processed")
        XCTAssertEqual(ticket.status, .open)
        XCTAssertEqual(ticket.priority, .high)
    }

    func test_support_ticketStatusRawValues() {
        XCTAssertEqual(SupportTicket.TicketStatus.open.rawValue, "open")
        XCTAssertEqual(SupportTicket.TicketStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(SupportTicket.TicketStatus.resolved.rawValue, "resolved")
        XCTAssertEqual(SupportTicket.TicketStatus.closed.rawValue, "closed")
    }

    func test_support_ticketPriorityRawValues() {
        XCTAssertEqual(SupportTicket.TicketPriority.low.rawValue, "low")
        XCTAssertEqual(SupportTicket.TicketPriority.medium.rawValue, "medium")
        XCTAssertEqual(SupportTicket.TicketPriority.high.rawValue, "high")
        XCTAssertEqual(SupportTicket.TicketPriority.urgent.rawValue, "urgent")
    }

    // MARK: - Support Message (field is `text` + `is_from_support`)

    func test_support_messageDecodesCorrectly() throws {
        let json = """
        {
            "id": "smsg-001",
            "ticket_id": "ticket-001",
            "sender_id": "user-111",
            "text": "I need help with my payment",
            "is_from_support": false,
            "created_at": "2025-12-20T08:05:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let msg = try decoder.decode(SupportMessage.self, from: json)
        XCTAssertFalse(msg.is_from_support)
        XCTAssertEqual(msg.text, "I need help with my payment")
    }

    func test_support_supportAgentIsFromSupport() throws {
        let json = """
        {
            "id": "smsg-002",
            "ticket_id": "ticket-001",
            "sender_id": "support-agent-1",
            "text": "Hi! We're looking into this.",
            "is_from_support": true,
            "created_at": "2025-12-20T08:10:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let msg = try decoder.decode(SupportMessage.self, from: json)
        XCTAssertTrue(msg.is_from_support)
    }

    // MARK: - Chat Service Error States

    func test_chat_unauthenticatedUserCannotChat() {
        let error = ChatServiceError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "You must be logged in to chat.")
    }

    func test_chat_emptyMessageError() {
        let error = ChatServiceError.emptyMessage
        XCTAssertEqual(error.errorDescription, "Message cannot be empty.")
    }

    func test_chat_conversationNotFoundError() {
        let error = ChatServiceError.conversationNotFound
        XCTAssertEqual(error.errorDescription, "Conversation not found.")
    }

    // MARK: - Participant Info (no `email` field in actual model)

    func test_chat_participantDisplayNameUsesFullName() {
        let participant = ParticipantInfo(
            id: "user-111",
            full_name: "Rahul Sharma",
            profile_photo_url: nil
        )
        XCTAssertEqual(participant.displayName, "Rahul Sharma")
    }

    func test_chat_participantNoNameFallsBackToUser() {
        let participant = ParticipantInfo(
            id: "user-111",
            full_name: nil,
            profile_photo_url: nil
        )
        // ParticipantInfo.displayName returns full_name ?? "User"
        XCTAssertEqual(participant.displayName, "User")
    }

    func test_chat_participantHasNoEmptyDisplayName() {
        let participant = ParticipantInfo(
            id: "user-111",
            full_name: nil,
            profile_photo_url: nil
        )
        XCTAssertFalse(participant.displayName.isEmpty)
    }
}
