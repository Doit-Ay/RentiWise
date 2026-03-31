import XCTest
@testable import RentiWise

final class ChatServiceErrorTests: XCTestCase {

    func testNotAuthenticatedErrorDescription() {
        let error = ChatServiceError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "You must be logged in to chat.")
    }

    func testEmptyMessageErrorDescription() {
        let error = ChatServiceError.emptyMessage
        XCTAssertEqual(error.errorDescription, "Message cannot be empty.")
    }

    func testConversationNotFoundErrorDescription() {
        let error = ChatServiceError.conversationNotFound
        XCTAssertEqual(error.errorDescription, "Conversation not found.")
    }

    func testMessageSendFailedErrorDescription() {
        let error = ChatServiceError.messageSendFailed
        XCTAssertEqual(error.errorDescription, "Failed to send message.")
    }

    func testAllCasesHaveDescriptions() {
        let allCases: [ChatServiceError] = [.notAuthenticated, .emptyMessage, .conversationNotFound, .messageSendFailed]
        for error in allCases {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func testErrorConformsToLocalizedError() {
        let error: LocalizedError = ChatServiceError.notAuthenticated
        XCTAssertNotNil(error.errorDescription)
    }
}
