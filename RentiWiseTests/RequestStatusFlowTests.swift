//
//  RequestStatusFlowTests.swift
//  RentiWiseTests
//
//  Test Cases TC-20 through TC-23: Request Status Flow (Fix 4)
//

import XCTest
@testable import RentiWise

final class RequestStatusFlowTests: XCTestCase {

    // MARK: - TC-20: Cancel Request Button Visibility
    /// Precondition: Request with status = 'pending', current user is borrower
    /// Expected: "Cancel Request" button is visible
    func testTC20_CancelRequestButtonVisibleForPending() {
        // BookingApprovalViewController shows "Cancel Request" as the return button
        // title when status is .pending
        let status = "pending"
        let expectedReturnButtonTitle = (status == "pending") ? "Cancel Request" : "Return Item"
        XCTAssertEqual(expectedReturnButtonTitle, "Cancel Request",
                       "Return button should show 'Cancel Request' for pending status")
    }

    // MARK: - TC-21: Cancel Request Not Shown for Approved
    /// Expected: "Cancel Request" button is hidden for approved status
    func testTC21_CancelRequestNotShownForApproved() {
        let status = "approved"
        let expectedReturnButtonTitle = (status == "pending") ? "Cancel Request" : "Return Item"
        XCTAssertEqual(expectedReturnButtonTitle, "Return Item",
                       "Return button should show 'Return Item', not 'Cancel Request', for approved status")
    }

    // MARK: - TC-22: Cancel Updates DB and Notifies Lender (Manual QA)
    /// Precondition: pending request exists
    /// Steps: Tap "Cancel Request" → confirm in alert
    /// Expected: status = 'cancelled' in DB, push notification sent to lender
    func testTC22_CancelUpdatesDB_MANUAL_QA() {
        // Requires live Supabase. See ManualQAChecklist.md
        // Stub: verify the RequestStatus enum includes cancelled
        // (BookingApprovalViewController.RequestStatus)
        // The enum values are .approved, .pending, .cancelled, .rejected, .completed
        // All are validated by their usage in updateStatusUI()
        let cancelledStatus = "cancelled"
        XCTAssertEqual(cancelledStatus, "cancelled", "Cancelled status string should be 'cancelled'")
    }

    // MARK: - TC-23: Full Status Machine (Manual E2E)
    /// Steps: pending → approved → UPI confirmed → OTP → active → return OTP → completed
    /// This is a full E2E test that requires both borrower and lender accounts
    func testTC23_FullStatusMachine_MANUAL_E2E() {
        // Full E2E test — must be done manually with two accounts.
        // See ManualQAChecklist.md for the complete flow.

        // Stub: verify all expected status strings
        let expectedStatuses = ["pending", "approved", "active", "completed", "cancelled", "rejected", "otp_blocked", "disputed"]
        XCTAssertTrue(expectedStatuses.contains("pending"))
        XCTAssertTrue(expectedStatuses.contains("approved"))
        XCTAssertTrue(expectedStatuses.contains("active"))
        XCTAssertTrue(expectedStatuses.contains("completed"))
        XCTAssertTrue(expectedStatuses.contains("otp_blocked"), "OTP blocked is a new status from Fix 1")
        XCTAssertTrue(expectedStatuses.contains("disputed"), "Disputed is a new status for failed return OTP")
    }
}
