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

    func loadOrCreatePickupCode(requestId: String) async throws -> String {
        let request = try await fetchRequest(requestId: requestId)
        try await assertBorrowerAccess(for: request)

        if request.rentalStatus == .approved {
            throw makeError("Pickup has already been verified for this rental.")
        }

        guard request.rentalStatus == .accepted else {
            throw makeError("Pickup OTP is only available after the request is accepted.")
        }

        if let existingCode = try await fetchStoredPickupCode(for: request) {
            return existingCode
        }

        return try await regeneratePickupCode(requestId: requestId)
    }

    func regeneratePickupCode(requestId: String) async throws -> String {
        let request = try await fetchRequest(requestId: requestId)
        try await assertBorrowerAccess(for: request)

        guard request.rentalStatus == .accepted else {
            throw makeError("Pickup OTP can only be generated while the request is awaiting handoff.")
        }

        let code = generateCode()
        try await storePickupCode(code, for: request)
        return code
    }

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

        guard let expectedCode = try await fetchStoredPickupCode(for: request) else {
            throw makeError("The borrower has not generated a pickup OTP yet.")
        }

        guard expectedCode == trimmedOTP else {
            throw makeError("The code doesn't match the borrower's pickup OTP.")
        }

        struct VerificationPatch: Encodable {
            let status: String
            let pickup_code: String?
        }

        do {
            _ = try await client
                .from("requests")
                .update(VerificationPatch(status: "approved", pickup_code: nil))
                .eq("id", value: requestId)
                .eq("owner_id", value: request.owner_id)
                .execute()
        } catch {
            if RequestSchemaSupport.isMissingPickupCodeError(error) {
                RequestSchemaSupport.markPickupCodeUnavailable()
                struct StatusOnlyPatch: Encodable { let status: String }
                _ = try await client
                    .from("requests")
                    .update(StatusOnlyPatch(status: "approved"))
                    .eq("id", value: requestId)
                    .eq("owner_id", value: request.owner_id)
                    .execute()
            } else {
                throw error
            }
        }

        try await clearStoredPickupCode(for: request)

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
    }

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
        return userId
    }

    private struct PaymentPickupRow: Decodable {
        let id: String
        let pickup_code: String?
    }

    private struct PaymentPickupPatch: Encodable {
        let pickup_code: String?
    }

    private func fetchStoredPickupCode(for request: RequestWithItem) async throws -> String? {
        if let requestCode = request.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines),
           !requestCode.isEmpty {
            return requestCode
        }

        if let payment = try await fetchLatestPayment(requestId: request.id),
           let paymentCode = payment.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines),
           !paymentCode.isEmpty {
            return paymentCode
        }

        if let paymentId = try await fetchLatestPayment(requestId: request.id)?.id,
           let eventCode = try await fetchEventBackedPickupCode(paymentId: paymentId) {
            return eventCode
        }

        return nil
    }

    private func storePickupCode(_ code: String, for request: RequestWithItem) async throws {
        if let payment = try await fetchLatestPayment(requestId: request.id) {
            do {
                _ = try await client
                    .from("payments")
                    .update(PaymentPickupPatch(pickup_code: code))
                    .eq("id", value: payment.id)
                    .execute()
                return
            } catch {
                debugLog("[PickupOTP] Could not persist pickup code on payment row: \(error.localizedDescription)")
            }

            do {
                try await insertEventBackedPickupCode(code, paymentId: payment.id)
                return
            } catch {
                debugLog("[PickupOTP] Could not persist pickup code in payment_events: \(error.localizedDescription)")
            }
        }

        guard RequestSchemaSupport.supportsPickupCode else {
            throw makeError("Pickup-code generation is still syncing. Please try again in a moment.")
        }

        struct PickupCodePatch: Encodable { let pickup_code: String }
        do {
            _ = try await client
                .from("requests")
                .update(PickupCodePatch(pickup_code: code))
                .eq("id", value: request.id)
                .eq("borrower_id", value: request.borrower_id)
                .select("id")
                .single()
                .execute()
        } catch {
            if RequestSchemaSupport.isMissingPickupCodeError(error) {
                RequestSchemaSupport.markPickupCodeUnavailable()
                throw makeError("Pickup-code generation is still syncing. Please try again in a moment.")
            }
            throw error
        }
    }

    private func clearStoredPickupCode(for request: RequestWithItem) async throws {
        if let payment = try await fetchLatestPayment(requestId: request.id) {
            do {
                _ = try await client
                    .from("payments")
                    .update(PaymentPickupPatch(pickup_code: nil))
                    .eq("id", value: payment.id)
                    .execute()
            } catch {
                debugLog("[PickupOTP] Could not clear pickup code on payment row: \(error.localizedDescription)")
            }
        }
    }

    private func fetchLatestPayment(requestId: String) async throws -> PaymentPickupRow? {
        let response = try await client
            .from("payments")
            .select("id,pickup_code")
            .eq("request_id", value: requestId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()

        let rows = try decoder.decode([PaymentPickupRow].self, from: response.data)
        return rows.first
    }

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
