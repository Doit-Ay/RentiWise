import Foundation
import Supabase

struct RentalPaymentContext {
    let requestId: String
    let itemId: String
    let ownerId: String
    let borrowerId: String
    let rentalFee: Double
    let depositAmount: Double

    var totalAmount: Double {
        rentalFee + depositAmount
    }
}

struct RentalPaymentState {
    let paymentId: String?
    let borrowerMarkedPaid: Bool
    let lenderConfirmedReceived: Bool

    static let empty = RentalPaymentState(
        paymentId: nil,
        borrowerMarkedPaid: false,
        lenderConfirmedReceived: false
    )
}

final class RentalPaymentStateService {
    static let shared = RentalPaymentStateService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetch(requestId: String) async throws -> RentalPaymentState {
        guard let payment = try await fetchLatestPayment(requestId: requestId) else {
            return .empty
        }

        let lenderConfirmed = try await hasEvent(paymentId: payment.id, eventType: "payment_received")
        let normalizedStatus = payment.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return RentalPaymentState(
            paymentId: payment.id,
            borrowerMarkedPaid: true,
            lenderConfirmedReceived: lenderConfirmed || normalizedStatus == "succeeded"
        )
    }

    @discardableResult
    func markBorrowerPaid(context: RentalPaymentContext) async throws -> RentalPaymentState {
        let paymentId: String
        if let existing = try await fetchLatestPayment(requestId: context.requestId) {
            paymentId = existing.id
        } else {
            struct PaymentIDRow: Decodable { let id: String }

            let payload = PaymentInsert(
                request_id: context.requestId,
                item_id: context.itemId,
                owner_id: context.ownerId,
                borrower_id: context.borrowerId,
                provider: "upi",
                status: "pending",
                currency: "INR",
                rental_fee: context.rentalFee,
                deposit_amount: context.depositAmount,
                total_amount: context.totalAmount
            )

            let response = try await client
                .from("payments")
                .insert(payload)
                .select("id")
                .single()
                .execute()

            paymentId = try JSONDecoder().decode(PaymentIDRow.self, from: response.data).id
        }

        try await insertEventIfNeeded(paymentId: paymentId, eventType: "payment_submitted")
        return try await fetch(requestId: context.requestId)
    }

    @discardableResult
    func confirmPaymentReceived(requestId: String) async throws -> RentalPaymentState {
        guard let payment = try await fetchLatestPayment(requestId: requestId) else {
            throw NSError(
                domain: "RentalPaymentStateService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "The borrower has not marked this payment as sent yet."]
            )
        }

        try await insertEventIfNeeded(paymentId: payment.id, eventType: "payment_received")

        struct StatusUpdate: Encodable {
            let status: String
        }

        do {
            try await client
                .from("payments")
                .update(StatusUpdate(status: "succeeded"))
                .eq("id", value: payment.id)
                .execute()
        } catch {
            debugLog("[RentalPayment] Non-fatal status update failure: \(error.localizedDescription)")
        }

        return try await fetch(requestId: requestId)
    }

    private func fetchLatestPayment(requestId: String) async throws -> PaymentSummary? {
        let response = try await client
            .from("payments")
            .select("id,status")
            .eq("request_id", value: requestId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([PaymentSummary].self, from: response.data)
        return rows.first
    }

    private func hasEvent(paymentId: String, eventType: String) async throws -> Bool {
        let response = try await client
            .from("payment_events")
            .select("event_type")
            .eq("payment_id", value: paymentId)
            .eq("event_type", value: eventType)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([PaymentEventSummary].self, from: response.data)
        return !rows.isEmpty
    }

    private func insertEventIfNeeded(paymentId: String, eventType: String) async throws {
        let alreadyExists = try await hasEvent(paymentId: paymentId, eventType: eventType)
        guard !alreadyExists else { return }

        let payload = PaymentEventInsert(
            payment_id: paymentId,
            event_type: eventType,
            raw_payload: nil
        )

        try await client
            .from("payment_events")
            .insert(payload)
            .execute()
    }
}

private struct PaymentSummary: Decodable {
    let id: String
    let status: String
}

private struct PaymentEventSummary: Decodable {
    let event_type: String
}
