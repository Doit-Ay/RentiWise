//
//  ManualQAChecklist.swift
//  RentiWiseTests
//
//  Manual QA Checklist for flows requiring live Supabase + two accounts
//  Run all SQL migrations and deploy Edge Functions before testing.
//
//  NOTE: This file does NOT contain runnable XCTest methods.
//  It is a structured QA reference document for manual testers.
//

/*
═══════════════════════════════════════════════════════════════════
 MANUAL QA CHECKLIST — RentiWise Phase 1 (6 Fixes)
═══════════════════════════════════════════════════════════════════

 PREREQUISITES:
 ✅ SQL migration 001_otp_upi_fixes.sql executed in Supabase Dashboard
 ✅ Edge Functions deployed: generate-otp, verify-pickup-otp, verify-return-otp
 ✅ New Swift files added to Xcode target
 ✅ Two test accounts: Borrower (Account A) and Lender (Account B)
 ✅ Lender has a valid upi_id set in their profile

═══════════════════════════════════════════════════════════════════
 FIX 1 — OTP SYSTEM (TC-05, TC-06, TC-07, TC-08, TC-09, TC-10)
═══════════════════════════════════════════════════════════════════

 QA-OTP-1: Complete Pickup OTP Flow
 ───────────────────────────────────
 1. Borrower (A) submits a rental request for Lender (B)'s item
 2. Lender (B) approves the request → status becomes 'approved'
 3. Borrower (A) opens the approved request
 4. Borrower (A) confirms UPI payment → payment_confirmed_by_borrower = true
 5. Borrower (A) is navigated to BorrowerOTPViewController
 6. VERIFY: A 4-digit OTP is displayed in large monospaced text
 7. VERIFY: "Regenerate Code" button is disabled for 30 seconds
 8. VERIFY: In Supabase, requests.pickup_otp_hash is NOT the plaintext OTP
 9. Lender (B) opens the request → taps "Confirm Pickup with OTP"
 10. Lender (B) enters the CORRECT OTP shown on Borrower's screen
 11. VERIFY: Green checkmark animation plays
 12. VERIFY: In Supabase, requests.status = 'active', pickup_confirmed_at is set
 ✅ PASS if all verifications succeed

 QA-OTP-2: Wrong OTP + Lockout
 ──────────────────────────────
 1. Follow steps 1-8 from QA-OTP-1
 2. Lender enters WRONG OTP (attempt 1)
 3. VERIFY: Shake animation, error message "Incorrect code. 2 attempts remaining."
 4. Lender enters WRONG OTP (attempt 2)
 5. VERIFY: Error message "Incorrect code. 1 attempt remaining."
 6. Lender enters WRONG OTP (attempt 3)
 7. VERIFY: All inputs disabled, "Contact support" message
 8. VERIFY: In Supabase, requests.status = 'otp_blocked', otp_attempt_count = 3
 ✅ PASS if all verifications succeed

 QA-OTP-3: Return OTP Flow
 ──────────────────────────
 1. Start with an 'active' rental (complete pickup OTP first)
 2. Lender (B) opens the active request → generates return OTP
 3. VERIFY: Return OTP is displayed on Lender's screen
 4. VERIFY: In Supabase, requests.return_otp_hash is set (separate from pickup_otp_hash)
 5. Borrower (A) enters the return OTP
 6. VERIFY: Green checkmark animation
 7. VERIFY: In Supabase, requests.status = 'completed', return_confirmed_at is set
 ✅ PASS if all verifications succeed

 QA-OTP-4: Authorization — Wrong User Blocked
 ─────────────────────────────────────────────
 1. As Lender, attempt to call generate-otp with type='pickup' via API
 2. VERIFY: Edge Function returns 403 "Only the borrower can generate pickup OTP"
 3. As Borrower, attempt to call generate-otp with type='return' via API
 4. VERIFY: Edge Function returns 403 "Only the lender can generate return OTP"
 ✅ PASS if both calls are rejected

═══════════════════════════════════════════════════════════════════
 FIX 2 — UPI CONFIRMATION (TC-14)
═══════════════════════════════════════════════════════════════════

 QA-UPI-1: Payment Confirmation
 ───────────────────────────────
 1. Lender has upi_id = "test@paytm" set in their profile
 2. Borrower's request is approved
 3. Borrower taps "Proceed to Payment"
 4. VERIFY: UPIConfirmationViewController is shown (NOT the old action sheet)
 5. VERIFY: Shows lender UPI ID, rental total, deposit, grand total
 6. VERIFY: "Proceed to Pickup Code" button is DISABLED initially
 7. Tap "I confirm I have paid" checkbox
 8. VERIFY: Button becomes enabled (teal)
 9. Tap "Proceed to Pickup Code"
 10. VERIFY: In Supabase, requests.payment_confirmed_by_borrower = true
 11. VERIFY: BorrowerOTPViewController is pushed
 ✅ PASS if all verifications succeed

 QA-UPI-2: Open UPI App Deep Link
 ─────────────────────────────────
 1. On UPIConfirmationViewController, tap "Open UPI App"
 2. On a real device: VERIFY that a UPI-enabled app opens (GPay, PhonePe, etc.)
 3. On simulator: VERIFY that "No UPI App" alert is shown
 ✅ PASS if correct behavior on both device and simulator

═══════════════════════════════════════════════════════════════════
 FIX 3 — DUPLICATE REQUEST CHECK (TC-16, TC-17, TC-18, TC-19)
═══════════════════════════════════════════════════════════════════

 QA-DUP-1: Status-Based Button Blocking
 ───────────────────────────────────────
 1. As Borrower, create a request for Item X → status 'pending'
 2. Open Item X in ProductViewController
 3. VERIFY: "Rent Now" is disabled, shows "Request Pending"
 4. Lender approves → status 'approved'
 5. Open Item X again
 6. VERIFY: "Rent Now" is disabled, shows "Approved — Confirm Payment"
 7. Complete pickup OTP → status 'active'
 8. Open Item X again
 9. VERIFY: "Rent Now" is disabled, shows "Currently Renting"
 10. Complete return OTP → status 'completed'
 11. Open Item X again
 12. VERIFY: "Rent Now" is ENABLED again (label "Rent Now")
 ✅ PASS if all states show correct labels

═══════════════════════════════════════════════════════════════════
 FIX 4 — STATUS FLOW (TC-22, TC-23)
═══════════════════════════════════════════════════════════════════

 QA-STATUS-1: Full E2E Status Machine
 ─────────────────────────────────────
 1. Borrower submits request → VERIFY DB: status = 'pending'
 2. Lender approves → VERIFY DB: status = 'approved'
 3. Borrower confirms UPI → VERIFY DB: payment_confirmed_by_borrower = true
 4. Borrower gets OTP → Lender enters correct OTP → VERIFY DB: status = 'active'
 5. Lender generates return OTP → Borrower enters it → VERIFY DB: status = 'completed'
 ✅ PASS if every transition is correct and no stuck states

═══════════════════════════════════════════════════════════════════
 FIX 5 — UPI ID IN PROFILE (TC-25, TC-27, TC-28)
═══════════════════════════════════════════════════════════════════

 QA-PROFILE-1: UPI ID Save and Persist
 ──────────────────────────────────────
 1. Open Edit Profile → UPI section should be visible
 2. Enter "myname@upi" → Save
 3. VERIFY DB: users.upi_id = 'myname@upi'
 4. Re-open Edit Profile
 5. VERIFY: UPI field shows "myname@upi"
 ✅ PASS if value persists

 QA-PROFILE-2: UPI Warning Banner
 ─────────────────────────────────
 1. Ensure user has NO upi_id (null or empty in DB)
 2. Navigate to Add Item First screen
 3. VERIFY: Teal-bordered banner visible: "Add your UPI ID in Profile..."
 4. Tap "Go to Profile" → VERIFY: switches to Profile tab
 5. Set a UPI ID and save
 6. Return to Add Item First screen
 7. VERIFY: Banner is NOT shown
 ✅ PASS if banner appears/disappears correctly

═══════════════════════════════════════════════════════════════════
 FIX 6 — REVIEW GATE (TC-30)
═══════════════════════════════════════════════════════════════════

 QA-REVIEW-1: Review After Completed Rental
 ───────────────────────────────────────────
 1. User has NO completed rental for Item Y
 2. Open Item Y → VERIFY: "Write a Review" button is HIDDEN
 3. Complete a rental for Item Y (full E2E)
 4. Re-open Item Y → VERIFY: "Write a Review" button is VISIBLE
 5. Submit a review
 6. Re-open Item Y → VERIFY: Button says "Edit Review"
 ✅ PASS if all visible/hidden states correct
*/
