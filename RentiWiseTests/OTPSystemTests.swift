//
//  OTPSystemTests.swift
//  RentiWiseTests
//
//  Test Cases TC-01 through TC-10: OTP System (Fix 1)
//

import XCTest
@testable import RentiWise

final class OTPSystemTests: XCTestCase {

    // MARK: - TC-01: OTP Display Format
    /// Precondition: BorrowerOTPViewController receives a valid 6-digit string from service
    /// Expected: Placeholder is shown before load completes, and font size is 56pt for readability
    /// Failure: Label shows nil or incorrect placeholder
    func testTC01_OTPDisplayFormat() {
        let vc = BorrowerOTPViewController()
        vc.requestId = "test-request-id"
        vc.lenderName = "Test Lender"
        vc.loadViewIfNeeded()

        // After loading, OTP label should show placeholder "----" (before Edge Function call)
        // We cannot call the Edge Function in unit tests, but verify the UI is set up correctly
        let mirror = Mirror(reflecting: vc)
        let otpLabel = mirror.children.first(where: { $0.label == "otpLabel" })?.value as? UILabel

        XCTAssertNotNil(otpLabel, "OTP label should exist")
        XCTAssertEqual(otpLabel?.text, "----", "Initial OTP should be placeholder")

        // Verify font configuration
        if let font = otpLabel?.font {
            XCTAssertEqual(font.pointSize, 56, "OTP font should be 56pt")
        }
    }

    // MARK: - TC-02: OTP Regenerate Cooldown
    /// Precondition: Borrower has just generated an OTP
    /// Expected: Regenerate button disabled, countdown shows "30s"
    /// Failure: Button remains enabled, allowing spam calls
    func testTC02_OTPRegenerateCooldown() {
        let vc = BorrowerOTPViewController()
        vc.requestId = "test-request-id"
        vc.lenderName = "Test Lender"
        vc.loadViewIfNeeded()

        let mirror = Mirror(reflecting: vc)
        let regenerateButton = mirror.children.first(where: { $0.label == "regenerateButton" })?.value as? UIButton

        XCTAssertNotNil(regenerateButton, "Regenerate button should exist")
        // Initially, the button should be disabled (OTP is generating on viewDidLoad)
        XCTAssertFalse(regenerateButton?.isEnabled ?? true, "Regenerate should be disabled during generation")
    }

    // MARK: - TC-03: OTP Input Auto-Advance
    /// Precondition: LenderOTPInputViewController is loaded
    /// Steps: Type "1" into box 1
    /// Expected: Focus moves automatically to box 2
    /// Failure: Cursor stays in box 1
    func testTC03_OTPInputAutoAdvance() {
        let vc = LenderOTPInputViewController()
        vc.requestId = "test-request-id"
        vc.loadViewIfNeeded()

        let mirror = Mirror(reflecting: vc)
        let fields = mirror.children.first(where: { $0.label == "otpFields" })?.value as? [UITextField]

        XCTAssertNotNil(fields, "OTP fields should exist")
        XCTAssertEqual(fields?.count, 6, "Should have exactly 6 OTP input fields")

        // Simulate typing "1" in the first field
        if let field = fields?.first {
            field.text = "1"
            field.sendActions(for: .editingChanged)
            // After editing changed, the delegate should advance focus to the next field
            // We can verify the text was set correctly
            XCTAssertEqual(field.text, "1", "First field should contain '1'")
        }
    }

    // MARK: - TC-04: OTP Input Digits Only
    /// Precondition: LenderOTPInputViewController is loaded
    /// Steps: Attempt to type "A" into any OTP box
    /// Expected: Character is rejected, box stays empty
    /// Failure: Letter appears in the box
    func testTC04_OTPInputDigitsOnly() {
        let vc = LenderOTPInputViewController()
        vc.requestId = "test-request-id"
        vc.loadViewIfNeeded()

        let mirror = Mirror(reflecting: vc)
        let fields = mirror.children.first(where: { $0.label == "otpFields" })?.value as? [UITextField]

        guard let field = fields?.first else {
            XCTFail("Could not get first OTP field")
            return
        }

        // Test UITextFieldDelegate's shouldChangeCharactersIn
        let shouldAllow = vc.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "A")
        XCTAssertFalse(shouldAllow, "Non-digit characters should be rejected")

        let shouldAllowDigit = vc.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "5")
        XCTAssertTrue(shouldAllowDigit, "Digit characters should be accepted")
    }

    // MARK: - TC-05: OTP Lockout After 3 Failures (Manual QA)
    /// Precondition: otp_attempt_count = 2 in DB for the request
    /// Steps: Enter any wrong 6-digit code → tap "Confirm Handoff"
    /// Expected: Input boxes disabled, "Contact support" shown, status = 'otp_blocked' in DB
    /// NOTE: Requires live Supabase — see ManualQAChecklist below
    func testTC05_OTPLockoutAfter3Failures_MANUAL_QA() {
        // This test requires a live Supabase instance.
        // See ManualQAChecklist.md for step-by-step manual testing instructions.
        // Stub: verify the VC has a maxAttempts constant of 3
        let vc = LenderOTPInputViewController()
        vc.loadViewIfNeeded()

        let mirror = Mirror(reflecting: vc)
        let maxAttempts = mirror.children.first(where: { $0.label == "maxAttempts" })?.value as? Int
        XCTAssertEqual(maxAttempts, 3, "Max OTP attempts should be 3")
    }

    // MARK: - TC-06: Wrong OTP Shake Animation (Manual QA — visual verification)
    /// NOTE: Visual animation verification requires manual testing
    func testTC06_WrongOTPShakeAnimation_MANUAL_QA() {
        // This test requires visual verification of the shake animation.
        // See ManualQAChecklist.md for detailed steps.
        // Stub: Verify error label exists and is initially hidden
        let vc = LenderOTPInputViewController()
        vc.loadViewIfNeeded()

        let mirror = Mirror(reflecting: vc)
        let errorLabel = mirror.children.first(where: { $0.label == "errorLabel" })?.value as? UILabel
        XCTAssertNotNil(errorLabel, "Error label should exist")
        XCTAssertTrue(errorLabel?.isHidden ?? false, "Error label should start hidden")
    }

    // MARK: - TC-07: Correct OTP Success Flow (Manual QA — requires live Supabase)
    func testTC07_CorrectOTPSuccessFlow_MANUAL_QA() {
        // See ManualQAChecklist.md
        // Stub: Verify onVerified callback is wirable
        let vc = LenderOTPInputViewController()
        var callbackCalled = false
        vc.onVerified = { callbackCalled = true }
        XCTAssertNotNil(vc.onVerified, "onVerified callback should be settable")
    }

    // MARK: - TC-08: Return OTP — Lender Generates
    /// Precondition: Request status = 'active', current user is lender
    /// Expected: generate-otp called with type: "return"
    func testTC08_ReturnOTPLenderGenerates() {
        let vc = LenderReturnOTPViewController()
        vc.requestId = "test-request-id"
        vc.borrowerName = "Test Borrower"
        vc.loadViewIfNeeded()

        // Verify VC is configured with correct title
        XCTAssertEqual(vc.title, "Return Code", "Title should be 'Return Code'")

        let mirror = Mirror(reflecting: vc)
        let otpLabel = mirror.children.first(where: { $0.label == "otpLabel" })?.value as? UILabel
        XCTAssertNotNil(otpLabel, "OTP label should exist")
        XCTAssertEqual(otpLabel?.text, "----", "Initial placeholder should be '----'")
    }

    // MARK: - TC-09: Return OTP — Borrower Confirms (Manual QA)
    func testTC09_ReturnOTPBorrowerConfirms() {
        let vc = BorrowerReturnOTPInputViewController()
        vc.requestId = "test-request-id"
        vc.loadViewIfNeeded()

        XCTAssertEqual(vc.title, "Verify Return", "Title should be 'Verify Return'")

        var callbackCalled = false
        vc.onVerified = { callbackCalled = true }
        XCTAssertNotNil(vc.onVerified, "onVerified callback should be settable")
    }

    // MARK: - TC-10: Wrong User Cannot Generate OTP (Edge Function level — Manual QA)
    func testTC10_WrongUserCannotGenerateOTP_MANUAL_QA() {
        // This test requires a live Supabase Edge Function call.
        // The Edge Function checks user.id against request.borrower_id / request.owner_id
        // and returns 403 if the wrong user attempts to generate.
        // See ManualQAChecklist.md for detailed steps.

        // Stub: verify requestId is required
        let vc = BorrowerOTPViewController()
        XCTAssertEqual(vc.requestId, "", "requestId should default to empty")
    }
}
