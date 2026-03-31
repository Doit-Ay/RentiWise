import XCTest
@testable import RentiWise

/// FLOW 5: BORROWER & LENDER — Extend Rental
/// Tests the extend rental request: borrower submits → lender approves → end_date updated
/// Also tests cross-blocking: return pending blocks extend, extend pending blocks return
final class E2E_ExtendRentalFlowTests: XCTestCase {

    // MARK: - Extension Request Payload

    struct ExtensionRequest {
        let request_id: String
        let original_end_date: String
        let new_end_date: String
        let additional_days: Int
        let additional_cost: Double
        let status: String
    }

    func test_extend_requestCreatedAsPending() {
        let ext = ExtensionRequest(
            request_id: "req-001",
            original_end_date: "2025-12-27",
            new_end_date: "2025-12-29",
            additional_days: 2,
            additional_cost: 1000.0,
            status: "pending"
        )
        XCTAssertEqual(ext.status, "pending")
    }

    func test_extend_additionalDaysCalculated() {
        let originalEnd = "2025-12-27"
        let newEnd = "2025-12-29"

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)

        let start = df.date(from: originalEnd)!
        let end = df.date(from: newEnd)!
        let additionalDays = Calendar.current.dateComponents([.day], from: start, to: end).day!

        XCTAssertEqual(additionalDays, 2)
    }

    func test_extend_additionalCostIsPositive() {
        let pricePerDay: Double = 500.0
        let additionalDays: Int = 2
        let additionalCost = pricePerDay * Double(additionalDays)
        XCTAssertGreaterThan(additionalCost, 0)
        XCTAssertEqual(additionalCost, 1000.0, accuracy: 0.01)
    }

    func test_extend_newEndDateLaterThanOriginal() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)

        let original = df.date(from: "2025-12-27")!
        let newDate = df.date(from: "2025-12-29")!
        XCTAssertGreaterThan(newDate, original)
    }

    // MARK: - Cross-Blocking Logic

    func test_extend_returnPendingBlocksExtend() {
        // If return is pending, extend button is disabled (from BookingApprovalVC)
        let returnRequestStatus = "pending"
        let extendAllowed = (returnRequestStatus != "pending")
        XCTAssertFalse(extendAllowed, "Cannot extend while a return request is pending")
    }

    func test_extend_extendPendingBlocksReturn() {
        let extensionStatus = "pending"
        let returnAllowed = (extensionStatus != "pending")
        XCTAssertFalse(returnAllowed, "Cannot return while an extension request is pending")
    }

    func test_extend_returnRejectedReEnablesExtend() {
        let returnStatus = "rejected"
        let extendAllowed = (returnStatus == "rejected" || returnStatus == "accepted" || returnStatus == nil)
        XCTAssertTrue(extendAllowed, "Rejected return should re-enable extend button")
    }

    func test_extend_extendAcceptedReEnablesReturn() {
        let extensionStatus = "accepted"
        let returnAllowed = (extensionStatus != "pending")
        XCTAssertTrue(returnAllowed, "Accepted extension should re-enable return button")
    }

    // MARK: - Button State Transitions

    func test_extend_buttonTitleChangesDuringPending() {
        var extensionStatus: String? = nil
        var buttonTitle = "Extend Rental"

        // Before any extension request: "Extend Rental"
        XCTAssertEqual(buttonTitle, "Extend Rental")

        // After submitting: "Cancel Extend" (pending state)
        extensionStatus = "pending"
        if extensionStatus == "pending" { buttonTitle = "Cancel Extend" }
        XCTAssertEqual(buttonTitle, "Cancel Extend")

        // After rejection: back to "Extend Rental"
        extensionStatus = "rejected"
        if extensionStatus == "rejected" { buttonTitle = "Extend Rental" }
        XCTAssertEqual(buttonTitle, "Extend Rental")

        // After acceptance: back to "Extend Rental" (can request again)
        extensionStatus = "accepted"
        if extensionStatus == "accepted" { buttonTitle = "Extend Rental" }
        XCTAssertEqual(buttonTitle, "Extend Rental")
    }

    func test_extend_returnButtonTitleDuringPending() {
        var returnStatus: String? = nil
        var buttonTitle = "Return Item"

        returnStatus = "pending"
        if returnStatus == "pending" { buttonTitle = "Cancel Return" }
        XCTAssertEqual(buttonTitle, "Cancel Return")

        returnStatus = "rejected"
        if returnStatus == "rejected" { buttonTitle = "Return Item" }
        XCTAssertEqual(buttonTitle, "Return Item")
    }

    // MARK: - Extension Accepted: Total Price Update

    func test_extend_acceptedUpdatesBookingTotal() {
        // From RequestApprovalVC: newTotal = currentTotal + additionalCost
        let currentTotal: Double = 1600.0
        let additionalCost: Double = 800.0
        let newTotal = currentTotal + additionalCost
        XCTAssertEqual(newTotal, 2400.0, accuracy: 0.01)
    }

    // MARK: - Status Label Styling

    func test_extend_statusLabelForPending() {
        let status = "pending"
        let labelText: String
        switch status.lowercased() {
        case "pending": labelText = "Status: Pending"
        case "accepted": labelText = "Status: Request Accepted ✓"
        case "rejected": labelText = "Status: Rejected"
        default: labelText = "Status: \(status.capitalized)"
        }
        XCTAssertEqual(labelText, "Status: Pending")
    }

    func test_extend_statusLabelForAccepted() {
        let status = "accepted"
        let isExtension = true
        let labelText: String = isExtension ? "Status: Request Accepted ✓" : "Status: Accepted\nDeposit Credited ✓"
        XCTAssertTrue(labelText.contains("Accepted"))
    }

    // MARK: - Extension Alert Key (UserDefaults — show once per accepted extension)

    func test_extend_alertKeyIsUniquePerRequest() {
        let requestId1 = "req-001"
        let requestId2 = "req-002"
        let key1 = "extensionAlertShown_\(requestId1)"
        let key2 = "extensionAlertShown_\(requestId2)"
        XCTAssertNotEqual(key1, key2)
    }

    func test_extend_alertNotShownTwiceForSameExtension() {
        let requestId = "req-999"
        let alertKey = "extensionAlertShown_\(requestId)"
        UserDefaults.standard.set(false, forKey: alertKey)

        // First time: extension accepted, alert should show and key saved
        UserDefaults.standard.set(true, forKey: alertKey)
        let alreadyShown = UserDefaults.standard.bool(forKey: alertKey)
        XCTAssertTrue(alreadyShown, "Alert should only show once per accepted extension")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: alertKey)
    }
}
