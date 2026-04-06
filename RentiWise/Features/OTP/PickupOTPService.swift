import Foundation
import Supabase

final class PickupOTPService {
    static let shared = PickupOTPService()
    static let manualConfirmationRequiredCode = 1001

    private let client: SupabaseClient
    private let decoder = JSONDecoder()

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Borrower: Load or Create Pickup Code

    /// Called by the borrower to load their pickup OTP.
    /// The OTP is auto-generated when the lender confirms payment (status = succeeded).
    /// If no OTP exists yet, one is created and stored on the payment row.
    func loadOrCreatePickupCode(requestId: String) async throws -> String {
        let request = try await fetchRequest(requestId: requestId)
        try await assertBorrowerAccess(for: request)

        if request.rentalStatus == .approved {
            throw makeError("Pickup has already been verified for this rental.")
        }

        guard request.rentalStatus == .accepted else {
            throw makeError("Pickup OTP is only available after the request is accepted.")
        }

        // Try to get existing code from payments table
        if let existingCode = try await fetchPickupCodeFromPayment(requestId: requestId) {
            return existingCode
        }

        // If no confirmed payment exists, check if payment exists at all
        guard let payment = try await fetchLatestConfirmedPayment(requestId: requestId) else {
            throw makeError("Payment must be confirmed before generating a pickup OTP.")
        }

        // Generate and store a new code
        let code = generateCode()
        try await storePickupCodeOnPayment(code, paymentId: payment.id)
        return code
    }

    // MARK: - Borrower: Regenerate Pickup Code

    func regeneratePickupCode(requestId: String) async throws -> String {
        let request = try await fetchRequest(requestId: requestId)
        try await assertBorrowerAccess(for: request)

        guard request.rentalStatus == .accepted else {
            throw makeError("Pickup OTP can only be generated while the request is awaiting handoff.")
        }

        guard let payment = try await fetchLatestConfirmedPayment(requestId: requestId) else {
            throw makeError("Payment must be confirmed before generating a pickup OTP.")
        }

        let code = generateCode()
        try await storePickupCodeOnPayment(code, paymentId: payment.id)
        return code
    }

    // MARK: - Lender: Verify Pickup Code

    func verifyPickupCode(requestId: String, otp: String) async throws {
        let trimmedOTP = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOTP.count == 6 else {
            throw makeError("Enter the full 6-digit code.")
        }

        let request = try await fetchRequest(requestId: requestId)
        try await assertOwnerAccess(for: request)

        if request.rentalStatus == .approved {
            return
        }

        guard request.rentalStatus == .accepted else {
            throw makeError("This request is no longer waiting for pickup verification.")
        }

        guard let payment = try await fetchLatestConfirmedPayment(requestId: requestId) else {
            throw makeError("No confirmed payment found for this request.")
        }

        guard let expectedCode = payment.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines),
              !expectedCode.isEmpty else {
            throw makeError("The borrower has not generated a pickup OTP yet.")
        }

        // Compare OTP codes
        if expectedCode == trimmedOTP {
            // ✅ OTP Matched — update pickupcode_status to "matched"
            try await updatePickupCodeStatus(paymentId: payment.id, status: "matched")

            // Update request status to approved
            try await approveRequest(requestId: requestId, ownerId: request.owner_id)

            // Clear the pickup code from payment after successful verification
            try await clearPickupCode(paymentId: payment.id)

            // Post-verification tasks
            await createRentalHistoryIfNeeded(for: request)

            let itemTitle = request.items?.title ?? "Item"
            RemoteNotificationService.sendPickupConfirmed(
                requestId: request.id,
                borrowerId: request.borrower_id,
                ownerId: request.owner_id,
                itemTitle: itemTitle
            )
            AnalyticsService.shared.trackPickupVerified(requestId: request.id)
            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
            NotificationCenter.default.post(name: BookingApprovalViewController.requestApprovedNotification, object: nil)
        } else {
            // ❌ OTP Does Not Match — update pickupcode_status to "not_matched"
            try await updatePickupCodeStatus(paymentId: payment.id, status: "not_matched")
            throw makeError("The code doesn't match the borrower's pickup OTP.")
        }
    }

    // MARK: - Private: DB Operations

    private struct PaymentPickupRow: Decodable {
        let id: String
        let pickup_code: String?
        let pickupcode_status: String?
        let status: String?
    }

    private func fetchLatestConfirmedPayment(requestId: String) async throws -> PaymentPickupRow? {
        let response = try await client
            .from("payments")
            .select("id,pickup_code,pickupcode_status,status")
            .eq("request_id", value: requestId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()

        let rows = try decoder.decode([PaymentPickupRow].self, from: response.data)
        guard let payment = rows.first else { return nil }

        if payment.status?.lowercased() == "succeeded" {
            return payment
        }

        // Fallback: check if the lender confirmed receipt via event
        struct EventRow: Decodable { let event_type: String }
        do {
            let eventRes = try await client
                .from("payment_events")
                .select("event_type")
                .eq("payment_id", value: payment.id)
                .eq("event_type", value: "payment_received")
                .limit(1)
                .execute()

            let events = try decoder.decode([EventRow].self, from: eventRes.data)
            if !events.isEmpty {
                return payment
            }
        } catch {
            debugLog("[PickupOTP] Failed to fetch events: \(error.localizedDescription)")
        }

        if let code = payment.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return payment
        }

        return nil
    }

    private func fetchPickupCodeFromPayment(requestId: String) async throws -> String? {
        guard let payment = try await fetchLatestConfirmedPayment(requestId: requestId) else {
            return nil
        }

        if let code = payment.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty {
            return code
        }

        // Fallback: check payment_events for a stored code
        if let eventCode = try await fetchEventBackedPickupCode(paymentId: payment.id) {
            return eventCode
        }

        return nil
    }

    private struct PickupCodePatch: Encodable {
        let pickup_code: String
        let pickupcode_status: String
    }

    private func storePickupCodeOnPayment(_ code: String, paymentId: String) async throws {
        do {
            _ = try await client
                .from("payments")
                .update(PickupCodePatch(pickup_code: code, pickupcode_status: "pending"))
                .eq("id", value: paymentId)
                .execute()
        } catch {
            debugLog("[PickupOTP] Could not persist pickup code on payment row: \(error.localizedDescription)")
            // Fallback: store in payment_events
            try await insertEventBackedPickupCode(code, paymentId: paymentId)
        }
    }

    private struct PickupStatusPatch: Encodable {
        let pickupcode_status: String
    }

    private func updatePickupCodeStatus(paymentId: String, status: String) async throws {
        _ = try await client
            .from("payments")
            .update(PickupStatusPatch(pickupcode_status: status))
            .eq("id", value: paymentId)
            .execute()
    }

    private struct ClearPickupCodePatch: Encodable {
        let pickup_code: String?
    }

    private func clearPickupCode(paymentId: String) async throws {
        do {
            _ = try await client
                .from("payments")
                .update(ClearPickupCodePatch(pickup_code: nil))
                .eq("id", value: paymentId)
                .execute()
        } catch {
            debugLog("[PickupOTP] Could not clear pickup code on payment row: \(error.localizedDescription)")
        }
    }

    private func approveRequest(requestId: String, ownerId: String) async throws {
        struct VerificationPatch: Encodable {
            let status: String
            let pickup_code: String?
        }

        do {
            _ = try await client
                .from("requests")
                .update(VerificationPatch(status: "approved", pickup_code: nil))
                .eq("id", value: requestId)
                .eq("owner_id", value: ownerId)
                .execute()
        } catch {
            if RequestSchemaSupport.isMissingPickupCodeError(error) {
                RequestSchemaSupport.markPickupCodeUnavailable()
                struct StatusOnlyPatch: Encodable { let status: String }
                _ = try await client
                    .from("requests")
                    .update(StatusOnlyPatch(status: "approved"))
                    .eq("id", value: requestId)
                    .eq("owner_id", value: ownerId)
                    .execute()
            } else {
                throw error
            }
        }
    }

    // MARK: - Private: Request Fetching

    private func fetchRequest(requestId: String) async throws -> RequestWithItem {
        let select: String
        if RequestSchemaSupport.supportsPickupCode {
            select = """
            id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,pickup_code,status,created_at,
            items(id,title,images,price_per_day,category)
            """
        } else {
            select = """
            id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,
            items(id,title,images,price_per_day,category)
            """
        }

        do {
            let response = try await client
                .from("requests")
                .select(select)
                .eq("id", value: requestId)
                .single()
                .execute()

            return try decoder.decode(RequestWithItem.self, from: response.data)
        } catch {
            if RequestSchemaSupport.isMissingPickupCodeError(error) {
                RequestSchemaSupport.markPickupCodeUnavailable()
                return try await fetchRequest(requestId: requestId)
            }
            throw error
        }
    }

    // MARK: - Private: Access Control

    private func assertBorrowerAccess(for request: RequestWithItem) async throws {
        let currentUserId = try await currentUserId()
        guard currentUserId == request.borrower_id else {
            throw makeError("Only the borrower can generate this pickup OTP.")
        }
    }

    private func assertOwnerAccess(for request: RequestWithItem) async throws {
        let currentUserId = try await currentUserId()
        guard currentUserId == request.owner_id else {
            throw makeError("Only the lender can verify this pickup OTP.")
        }
    }

    private func currentUserId() async throws -> String {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            throw makeError("Sign in again to continue.")
        }
        return userId.lowercased()
    }

    // MARK: - Private: Event-based Fallback

    private func insertEventBackedPickupCode(_ code: String, paymentId: String) async throws {
        let payload = PaymentEventInsert(
            payment_id: paymentId,
            event_type: "pickup_code_generated",
            raw_payload: code
        )

        try await client
            .from("payment_events")
            .insert(payload)
            .execute()
    }

    private func fetchEventBackedPickupCode(paymentId: String) async throws -> String? {
        struct EventRow: Decodable {
            let raw_payload: String?
        }

        let response = try await client
            .from("payment_events")
            .select("raw_payload")
            .eq("payment_id", value: paymentId)
            .eq("event_type", value: "pickup_code_generated")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()

        let rows = try decoder.decode([EventRow].self, from: response.data)
        let code = rows.first?.raw_payload?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (code?.isEmpty == false) ? code : nil
    }

    // MARK: - Private: Helpers

    private func generateCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    private func makeError(_ message: String, code: Int = 0) -> NSError {
        NSError(
            domain: "Rentiwise.PickupOTP",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func makeManualConfirmationRequiredError(_ message: String) -> NSError {
        makeError(message, code: Self.manualConfirmationRequiredCode)
    }

    static func isManualConfirmationRequiredError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "Rentiwise.PickupOTP" && nsError.code == manualConfirmationRequiredCode
    }

    // MARK: - Private: Rental History

    private func createRentalHistoryIfNeeded(for request: RequestWithItem) async {
        struct ExistingHistoryRow: Decodable { let id: String }
        struct HistoryInsert: Encodable {
            let item_id: String
            let owner_id: String
            let borrower_id: String
            let start_date: String
            let end_date: String
            let total_amount: Double
            let request_id: String
        }

        do {
            let existing = try await client
                .from("rentals_history")
                .select("id")
                .eq("request_id", value: request.id)
                .limit(1)
                .execute()

            let rows = try decoder.decode([ExistingHistoryRow].self, from: existing.data)
            if !rows.isEmpty {
                return
            }
        } catch {
            debugLog("[PickupOTP] Could not check rental history: \(error.localizedDescription)")
        }

        let sqlDateFormatter = DateFormatter()
        sqlDateFormatter.calendar = Calendar(identifier: .gregorian)
        sqlDateFormatter.timeZone = .current
        sqlDateFormatter.dateFormat = "yyyy-MM-dd"

        var dayCount = 1
        if let startDate = sqlDateFormatter.date(from: request.start_date),
           let endDate = sqlDateFormatter.date(from: request.end_date) {
            dayCount = max(1, Int(ceil(endDate.timeIntervalSince(startDate) / 86400.0)))
        }

        let totalAmount = Double(dayCount) * (request.items?.price_per_day ?? 0)
        let payload = HistoryInsert(
            item_id: request.item_id,
            owner_id: request.owner_id,
            borrower_id: request.borrower_id,
            start_date: request.start_date,
            end_date: request.end_date,
            total_amount: totalAmount,
            request_id: request.id
        )

        do {
            _ = try await client
                .from("rentals_history")
                .insert(payload)
                .execute()
        } catch {
            debugLog("[PickupOTP] Failed to create rental history: \(error.localizedDescription)")
        }
    }
}
