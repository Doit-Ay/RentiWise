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
    /// Precondition: Request with status = 'pending' or 'accepted', current user is borrower
    /// Expected: "Cancel Request" button is visible until pickup is verified
    func testTC20_CancelRequestButtonVisibleForPending() {
        XCTAssertEqual(RentalStatus.pending.borrowerPrimaryActionTitle, "Cancel Request")
        XCTAssertEqual(RentalStatus.accepted.borrowerPrimaryActionTitle, "Cancel Request")
        XCTAssertTrue(RentalStatus.pending.borrowerPrimaryActionIsDestructive)
        XCTAssertTrue(RentalStatus.accepted.borrowerPrimaryActionIsDestructive)
    }

    // MARK: - TC-21: Cancel Request Not Shown for Approved
    /// Expected: "Cancel Request" button is hidden for approved status
    func testTC21_CancelRequestNotShownForApproved() {
        XCTAssertEqual(RentalStatus.approved.borrowerPrimaryActionTitle, "Return Item")
        XCTAssertEqual(RentalStatus.returned.borrowerPrimaryActionTitle, "Return Item")
        XCTAssertFalse(RentalStatus.approved.borrowerPrimaryActionIsDestructive)
        XCTAssertTrue(RentalStatus.approved.borrowerShowsExtendAndReturnActions)
    }

    // MARK: - TC-22: Cancel Updates DB and Notifies Lender (Manual QA)
    /// Precondition: pending request exists
    /// Steps: Tap "Cancel Request" → confirm in alert
    /// Expected: status = 'cancelled' in DB, push notification sent to lender
    func testTC22_CancelUpdatesDB_MANUAL_QA() {
        XCTAssertTrue(RentalStatus.pending.canTransition(to: .cancelled))
        XCTAssertTrue(RentalStatus.accepted.canTransition(to: .cancelled))
        XCTAssertFalse(RentalStatus.approved.canTransition(to: .cancelled))
    }

    // MARK: - TC-23: Full Status Machine (Manual E2E)
    /// Steps: pending → approved → UPI confirmed → OTP → active → return OTP → completed
    /// This is a full E2E test that requires both borrower and lender accounts
    func testTC23_FullStatusMachine_MANUAL_E2E() {
        XCTAssertEqual(
            RentalStatus.allCases.map(\.rawValue).sorted(),
            ["accepted", "approved", "cancelled", "completed", "denied", "pending", "rejected", "returned"].sorted()
        )
        XCTAssertTrue(RentalStatus.pending.canTransition(to: .accepted))
        XCTAssertTrue(RentalStatus.accepted.canTransition(to: .approved))
        XCTAssertTrue(RentalStatus.approved.canTransition(to: .returned))
        XCTAssertTrue(RentalStatus.returned.canTransition(to: .completed))
    }
}
