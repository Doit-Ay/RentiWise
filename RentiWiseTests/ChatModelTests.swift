import XCTest
@testable import RentiWise

final class ChatModelTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - ChatMessage

    func testChatMessageDecoding() throws {
        let json = """
        {
            "id": "msg-1",
            "conversation_id": "conv-1",
            "sender_id": "user-1",
            "text": "Hello!",
            "created_at": "2025-12-01T10:30:00Z",
            "is_read": false
        }
        """.data(using: .utf8)!

        let msg = try makeDecoder().decode(ChatMessage.self, from: json)
        XCTAssertEqual(msg.id, "msg-1")
        XCTAssertEqual(msg.conversation_id, "conv-1")
        XCTAssertEqual(msg.sender_id, "user-1")
        XCTAssertEqual(msg.text, "Hello!")
        XCTAssertFalse(msg.is_read)
    }

    func testChatMessageIsCurrentUser() throws {
        let json = """
        {
            "id": "msg-2",
            "conversation_id": "conv-1",
            "sender_id": "user-A",
            "text": "Hi",
            "created_at": "2025-12-01T10:30:00Z",
            "is_read": true
        }
        """.data(using: .utf8)!

        let msg = try makeDecoder().decode(ChatMessage.self, from: json)
        XCTAssertTrue(msg.isCurrentUser(currentUserId: "user-A"))
        XCTAssertFalse(msg.isCurrentUser(currentUserId: "user-B"))
    }

    func testChatMessageFormattedTime() throws {
        let json = """
        {
            "id": "msg-3",
            "conversation_id": "conv-1",
            "sender_id": "user-1",
            "text": "Test",
            "created_at": "2025-12-01T10:30:00Z",
            "is_read": false
        }
        """.data(using: .utf8)!

        let msg = try makeDecoder().decode(ChatMessage.self, from: json)
        // formattedTime should return a non-empty string
        XCTAssertFalse(msg.formattedTime.isEmpty)
    }

    func testChatMessageEquality() throws {
        let json = """
        {
            "id": "msg-eq",
            "conversation_id": "conv-1",
            "sender_id": "user-1",
            "text": "Same",
            "created_at": "2025-12-01T10:30:00Z",
            "is_read": false
        }
        """.data(using: .utf8)!

        let msg1 = try makeDecoder().decode(ChatMessage.self, from: json)
        let msg2 = try makeDecoder().decode(ChatMessage.self, from: json)
        XCTAssertEqual(msg1, msg2)
    }

    // MARK: - ChatConversation

    func testChatConversationDecoding() throws {
        let json = """
        {
            "id": "conv-1",
            "item_id": "item-1",
            "lender_id": "user-A",
            "borrower_id": "user-B",
            "last_message": "Hey",
            "last_message_at": "2025-12-01T12:00:00Z",
            "created_at": "2025-12-01T10:00:00Z",
            "updated_at": "2025-12-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let conv = try makeDecoder().decode(ChatConversation.self, from: json)
        XCTAssertEqual(conv.id, "conv-1")
        XCTAssertEqual(conv.item_id, "item-1")
        XCTAssertEqual(conv.lender_id, "user-A")
        XCTAssertEqual(conv.borrower_id, "user-B")
        XCTAssertEqual(conv.last_message, "Hey")
    }

    func testChatConversationOtherParticipant() throws {
        let json = """
        {
            "id": "conv-2",
            "lender_id": "user-A",
            "borrower_id": "user-B",
            "created_at": "2025-12-01T10:00:00Z"
        }
        """.data(using: .utf8)!

        let conv = try makeDecoder().decode(ChatConversation.self, from: json)
        XCTAssertEqual(conv.otherParticipantId(currentUserId: "user-A"), "user-B")
        XCTAssertEqual(conv.otherParticipantId(currentUserId: "user-B"), "user-A")
    }

    // MARK: - ParticipantInfo

    func testParticipantInfoDisplayName() throws {
        let json = """
        { "id": "p1", "full_name": "John Doe", "profile_photo_url": null }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(ParticipantInfo.self, from: json)
        XCTAssertEqual(info.displayName, "John Doe")
    }

    func testParticipantInfoDisplayNameFallback() throws {
        let json = """
        { "id": "p2", "full_name": null, "profile_photo_url": null }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(ParticipantInfo.self, from: json)
        XCTAssertEqual(info.displayName, "User")
    }

    // MARK: - SupportTicket

    func testSupportTicketDecoding() throws {
        let json = """
        {
            "id": "t1",
            "user_id": "u1",
            "subject": "Help me",
            "status": "open",
            "priority": "medium",
            "created_at": "2025-12-01T10:00:00Z",
            "updated_at": null,
            "resolved_at": null
        }
        """.data(using: .utf8)!

        let ticket = try makeDecoder().decode(SupportTicket.self, from: json)
        XCTAssertEqual(ticket.id, "t1")
        XCTAssertEqual(ticket.subject, "Help me")
        XCTAssertEqual(ticket.status, .open)
        XCTAssertEqual(ticket.priority, .medium)
        XCTAssertNil(ticket.resolved_at)
    }

    func testSupportTicketStatusValues() {
        XCTAssertEqual(SupportTicket.TicketStatus.open.rawValue, "open")
        XCTAssertEqual(SupportTicket.TicketStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(SupportTicket.TicketStatus.resolved.rawValue, "resolved")
        XCTAssertEqual(SupportTicket.TicketStatus.closed.rawValue, "closed")
    }

    func testSupportTicketPriorityValues() {
        XCTAssertEqual(SupportTicket.TicketPriority.low.rawValue, "low")
        XCTAssertEqual(SupportTicket.TicketPriority.medium.rawValue, "medium")
        XCTAssertEqual(SupportTicket.TicketPriority.high.rawValue, "high")
        XCTAssertEqual(SupportTicket.TicketPriority.urgent.rawValue, "urgent")
    }
}
