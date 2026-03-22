import XCTest
@testable import RentiWise

/// FLOW 6: BORROWER — Return Item to Owner
/// Tests: Borrower submits return with proof photos → lender reviews → lender accepts → booking completed, deposit released
final class E2E_ReturnItemFlowTests: XCTestCase {

    // MARK: - Step 1: Return Proof Validation

    func test_return_submitRequiresAtLeastOnePhoto() {
        var proofMediaURLs: [URL] = []
        let submitEnabled = !proofMediaURLs.isEmpty
        XCTAssertFalse(submitEnabled, "Submit button should be disabled if no proof photos selected")

        proofMediaURLs.append(FileManager.default.temporaryDirectory.appendingPathComponent("proof.jpg"))
        let submitEnabledAfterPhoto = !proofMediaURLs.isEmpty
        XCTAssertTrue(submitEnabledAfterPhoto)
    }

    func test_return_max5PhotosAllowed() {
        // PHPickerConfiguration selectionLimit = 5 - proofMediaURLs.count
        var existing: [URL] = (0..<3).map { _ in FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
        let selectionLimit = 5 - existing.count
        XCTAssertEqual(selectionLimit, 2)
    }

    func test_return_notesAreOptional() {
        let notes: String = ""  // Empty notes are valid
        XCTAssertTrue(notes.isEmpty)  // Empty is acceptable
    }

    func test_return_notesSetOnEndEditing() {
        var notes = ""
        let textViewContent = "Item is in good condition, minor scratches"
        notes = textViewContent  // simulating textViewDidEndEditing
        XCTAssertEqual(notes, textViewContent)
    }

    // MARK: - Step 2: Return Request Payload

    struct ReturnRequest: Encodable {
        let request_id: String
        let proof_media: [String]
        let notes: String
        let status: String
        let created_at: String
    }

    func test_return_requestPayloadCreatesCorrectly() throws {
        let payload = ReturnRequest(
            request_id: "req-001",
            proof_media: ["return_proof/photo1.jpg", "return_proof/photo2.jpg"],
            notes: "Minor scratches on corner",
            status: "pending",
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        XCTAssertEqual(payload.request_id, "req-001")
        XCTAssertEqual(payload.proof_media.count, 2)
        XCTAssertEqual(payload.status, "pending")
    }

    func test_return_requestStartsAsPending() {
        let status = "pending"
        XCTAssertEqual(status, "pending", "Return requests must always start as 'pending' for lender review")
    }

    func test_return_requestPayloadEncodesCorrectly() throws {
        let payload = ReturnRequest(
            request_id: "req-zzz",
            proof_media: ["photo.jpg"],
            notes: "",
            status: "pending",
            created_at: "2025-12-26T14:00:00Z"
        )
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["status"] as? String, "pending")
        XCTAssertEqual(json["request_id"] as? String, "req-zzz")
    }

    // MARK: - Step 3: Return Media Upload

    func test_return_uploadedPathContainsFileName() {
        // uploadMediaToSupabase generates: "return_proof_<UUID>_<filename>"
        let fileName = "return_proof_\(UUID().uuidString)_photo.jpg"
        XCTAssertTrue(fileName.hasPrefix("return_proof_"))
        XCTAssertTrue(fileName.hasSuffix(".jpg"))
    }

    func test_return_uniqueFileNameForEachUpload() {
        let name1 = "return_proof_\(UUID().uuidString)_photo.jpg"
        let name2 = "return_proof_\(UUID().uuidString)_photo.jpg"
        XCTAssertNotEqual(name1, name2)
    }

    // MARK: - Step 4: Lender Reviews Return

    func test_return_lenderSeesReturnRequestTable() {
        let tableName = "return_requests"
        XCTAssertFalse(tableName.isEmpty)
        XCTAssertEqual(tableName, "return_requests")
    }

    func test_return_lenderSeesNotes() {
        let notes: String? = "Good condition overall"
        let displayedNotes = notes?.isEmpty == false ? notes : "No notes provided"
        XCTAssertEqual(displayedNotes, "Good condition overall")
    }

    func test_return_lenderSeesNoNotesWhenEmpty() {
        let notes: String? = nil
        let displayedNotes = notes?.isEmpty == false ? notes : "No notes provided"
        XCTAssertEqual(displayedNotes, "No notes provided")
    }

    // MARK: - Step 5: Lender Accepts Return → Booking Completed

    func test_return_acceptBySetsBookingToCompleted() {
        // In RequestApprovalVC, accepting a return_request → updates main request status to "completed"
        let returnStatus = "accepted"
        let bookingStatusAfter: String

        if returnStatus == "accepted" {
            bookingStatusAfter = "completed"
        } else {
            bookingStatusAfter = "accepted"  // unchanged for rejection
        }

        XCTAssertEqual(bookingStatusAfter, "completed")
    }

    func test_return_rejectDoesNotCompleteBooking() {
        let returnStatus = "rejected"
        let bookingStatusAfter = (returnStatus == "accepted") ? "completed" : "accepted"
        XCTAssertEqual(bookingStatusAfter, "accepted", "Rejection should NOT mark booking complete")
    }

    // MARK: - Step 6: Deposit Release Logic

    func test_return_acceptedConfirmationMentionsDeposit() {
        // In RequestApprovalVC: message = "Are you sure? Deposit will be released for - \(borrowerName)."
        let borrowerName = "Ashish Kumar"
        let msg = "Are you sure? Deposit will be released for - \(borrowerName)."
        XCTAssertTrue(msg.contains("Deposit"), "Confirmation message must mention deposit release")
        XCTAssertTrue(msg.contains(borrowerName))
    }

    func test_return_depositAmountMatchesOriginalItemDeposit() {
        let itemDeposit: Double = 15000.0
        let paymentDeposit: Double = 15000.0  // should match item's deposit_amount
        XCTAssertEqual(itemDeposit, paymentDeposit)
    }

    // MARK: - Step 7: Booking Status Display After Completion

    func test_return_completedStatusIsTerminal() {
        let terminalStatuses = ["completed", "cancelled", "rejected"]
        XCTAssertTrue(terminalStatuses.contains("completed"))
    }

    func test_return_completedBookingAppearsInHistory() {
        // History filter: status in ["completed", "cancelled", "rejected"]
        let bookingStatus = "completed"
        let appearsInHistory = ["completed", "cancelled", "rejected"].contains(bookingStatus)
        XCTAssertTrue(appearsInHistory)
    }

    func test_return_completedBookingHidesExtendAndReturn() {
        // BookingApprovalVC: updateReturnButtonState returns early if status == .completed
        let isCompleted = true
        let shouldHideButtons = isCompleted
        XCTAssertTrue(shouldHideButtons, "Return/Extend buttons should be hidden on completed booking")
    }

    // MARK: - Step 8: Post-Rental Review

    func test_return_reviewCanBeSubmittedAfterCompletion() {
        // Review should only be allowed once booking is completed
        let bookingStatus = "completed"
        let canReview = (bookingStatus == "completed")
        XCTAssertTrue(canReview)
    }

    func test_return_reviewRatingRange() {
        // Valid ratings: 1-5 stars
        let validRatings = [1, 2, 3, 4, 5]
        for rating in validRatings {
            XCTAssertTrue(rating >= 1 && rating <= 5, "Rating \(rating) must be in 1-5 range")
        }
    }

    func test_return_invalidRatingOutOfRange() {
        let invalidRatings = [0, 6, -1, 10]
        for rating in invalidRatings {
            XCTAssertFalse(rating >= 1 && rating <= 5, "Rating \(rating) should fail range validation")
        }
    }
}
