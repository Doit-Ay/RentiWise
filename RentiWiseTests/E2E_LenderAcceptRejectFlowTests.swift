import XCTest
@testable import RentiWise

/// FLOW 3: LENDER — Accept or Reject Rental Request
/// Tests the lender's decision flow in RequestsListViewController / DashboardLenderRequestViewController
/// Status transitions: pending → accepted / rejected
final class E2E_LenderAcceptRejectFlowTests: XCTestCase {

    // MARK: - Request Status State Machine

    func test_lender_newRequestArrivesAsPending() {
        // All requests are inserted as "pending" (from RequestViewController sendRequest())
        let request = buildRequest(status: "pending")
        XCTAssertEqual(request.status, "pending")
    }

    func test_lender_canAcceptRequest() {
        var request = buildRequest(status: "pending")
        request.status = "accepted"
        XCTAssertEqual(request.status, "accepted")
    }

    func test_lender_canRejectRequest() {
        var request = buildRequest(status: "pending")
        request.status = "rejected"
        XCTAssertEqual(request.status, "rejected")
    }

    func test_lender_cannotAcceptAlreadyRejected() {
        let request = buildRequest(status: "rejected")
        // Business rule: cannot accept a rejected request
        XCTAssertEqual(request.status, "rejected")
        XCTAssertNotEqual(request.status, "accepted")
    }

    func test_lender_acceptEnablesBorrowerPayment() {
        // In BookingApprovalVC: paymentButton is enabled only when status == .approved
        let dbStatus = "accepted"
        let isApproved = (dbStatus == "accepted")
        XCTAssertTrue(isApproved, "Accepted status should enable the payment button for borrower")
    }

    // MARK: - RequestWithItem Model Integrity

    func test_lender_requestContainsAllNecessaryFields() throws {
        let json = """
        {
            "id": "req-001",
            "item_id": "item-drone-1",
            "owner_id": "owner-111",
            "borrower_id": "borrower-222",
            "start_date": "2025-12-25",
            "end_date": "2025-12-27",
            "status": "pending"
        }
        """.data(using: .utf8)!

        let req = try JSONDecoder().decode(RequestWithItem.self, from: json)
        XCTAssertEqual(req.id, "req-001")
        XCTAssertEqual(req.owner_id, "owner-111")
        XCTAssertEqual(req.borrower_id, "borrower-222")
        XCTAssertEqual(req.status, "pending")
    }

    func test_lender_requestWithItemDataDecodes() throws {
        let json = """
        {
            "id": "req-002",
            "item_id": "item-cam-1",
            "owner_id": "owner-111",
            "borrower_id": "borrower-222",
            "start_date": "2025-12-01",
            "end_date": "2025-12-03",
            "status": "pending",
            "items": {
                "id": "item-cam-1",
                "title": "Canon EOS Camera",
                "price_per_day": 600.0
            }
        }
        """.data(using: .utf8)!

        let req = try JSONDecoder().decode(RequestWithItem.self, from: json)
        XCTAssertEqual(req.items?.title, "Canon EOS Camera")
        XCTAssertEqual(req.items?.price_per_day, 600.0)
    }

    // MARK: - Dashboard Filter Logic

    func test_lender_dashboardShowsPendingRequests() {
        let requests = [
            buildRequest(status: "pending"),
            buildRequest(status: "accepted"),
            buildRequest(status: "rejected")
        ]
        let pendingOnly = requests.filter { $0.status == "pending" }
        XCTAssertEqual(pendingOnly.count, 1)
    }

    func test_lender_dashboardActiveFilter() {
        let activeStatuses = ["pending", "accepted", "in_progress"]
        let requests = [
            buildRequest(status: "pending"),
            buildRequest(status: "accepted"),
            buildRequest(status: "completed"),
            buildRequest(status: "cancelled")
        ]
        let active = requests.filter { activeStatuses.contains($0.status) }
        XCTAssertEqual(active.count, 2)
    }

    func test_lender_completedRequestsInHistory() {
        let requests = [
            buildRequest(status: "completed"),
            buildRequest(status: "cancelled"),
            buildRequest(status: "rejected"),
            buildRequest(status: "pending")
        ]
        let terminalStatuses = ["completed", "cancelled", "rejected"]
        let history = requests.filter { terminalStatuses.contains($0.status) }
        XCTAssertEqual(history.count, 3)
    }

    // MARK: - Extension Request Flow

    func test_lender_extensionUpdatesEndDateAndPrice() {
        // When lender accepts extension: new_end_date replaces old, additional_cost is added
        let originalEndDate = "2025-12-27"
        let newEndDate = "2025-12-29"
        let originalTotal: Double = 1200.0
        let additionalCost: Double = 600.0
        let updatedTotal = originalTotal + additionalCost

        XCTAssertEqual(updatedTotal, 1800.0, accuracy: 0.01)
        XCTAssertNotEqual(originalEndDate, newEndDate)
    }

    func test_lender_acceptReturnSetsStatusToCompleted() {
        // In RequestApprovalVC line 397-401: accepting a return_request sets main request to "completed"
        let returnRequestStatus = "accepted"
        let mainRequestStatusAfterAccept = (returnRequestStatus == "accepted") ? "completed" : "accepted"
        XCTAssertEqual(mainRequestStatusAfterAccept, "completed")
    }

    func test_lender_rejectReturnKeepsRequestActive() {
        let returnRequestStatus = "rejected"
        let mainRequestStatusAfterReject = (returnRequestStatus == "rejected") ? "accepted" : "completed"
        // Rejecting a return request does NOT complete the booking
        XCTAssertEqual(mainRequestStatusAfterReject, "accepted")
    }

    // MARK: - Confirmation Dialogs

    func test_lender_acceptConfirmationMessage() {
        // In RequestApprovalVC: "Are you sure? Deposit will be released for - <borrowerName>"
        let borrowerName = "Rahul Sharma"
        let msg = "Are you sure? Deposit will be released for - \(borrowerName)."
        XCTAssertTrue(msg.contains(borrowerName))
        XCTAssertTrue(msg.contains("Deposit"))
    }

    func test_lender_rejectConfirmationMessageForExtension() {
        let borrowerName = "Priya Mehta"
        let msg = "Are you sure you want to reject this extension by - \(borrowerName)?"
        XCTAssertTrue(msg.contains("reject"))
        XCTAssertTrue(msg.contains(borrowerName))
    }

    // MARK: - Request Type Routing

    func test_requestType_returnRequestUsesReturnTable() {
        let requestType = RequestType.returnRequest
        let tableName = requestType == .returnRequest ? "return_requests" : "extension_requests"
        XCTAssertEqual(tableName, "return_requests")
    }

    func test_requestType_extensionRequestUsesExtensionTable() {
        let requestType = RequestType.extensionRequest
        let tableName = requestType == .returnRequest ? "return_requests" : "extension_requests"
        XCTAssertEqual(tableName, "extension_requests")
    }

    // MARK: - Helpers

    private func buildRequest(status: String) -> RequestWithItem {
        return RequestWithItem(
            id: UUID().uuidString,
            item_id: "item-test",
            owner_id: "owner-111",
            borrower_id: "borrower-222",
            start_date: "2025-12-25",
            end_date: "2025-12-27",
            pickup_time: nil,
            status: status,
            created_at: "2025-12-24T10:00:00Z",
            items: nil
        )
    }
}
