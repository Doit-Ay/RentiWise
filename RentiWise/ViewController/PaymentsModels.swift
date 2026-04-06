import Foundation

struct PaymentInsert: Encodable {
    let request_id: String
    let item_id: String
    let owner_id: String
    let borrower_id: String
    let provider: String          // "apple_pay", "card", "cod"
    let status: String            // start with "pending"
    let currency: String          // e.g., "INR"
    let rental_fee: Double
    let deposit_amount: Double
    let total_amount: Double
}

struct PaymentUpdate: Encodable {
    let status: String?           // "succeeded", "failed", "refunded", etc.
    let pickup_code: String?      // set when succeeded
    let pickupcode_status: String? // "pending", "matched", "not_matched"
    let provider_payment_id: String?
    let provider_receipt_url: String?
    let failure_reason: String?
}

struct PaymentRow: Decodable {
    let id: String
    let request_id: String
    let item_id: String
    let owner_id: String
    let borrower_id: String
    let provider: String
    let status: String
    let currency: String
    let rental_fee: Double
    let deposit_amount: Double
    let total_amount: Double
    let pickup_code: String?
    let pickupcode_status: String?
    let pickup_confirmed: Bool?
    let provider_payment_id: String?
    let provider_receipt_url: String?
    let failure_reason: String?
    let created_at: String
    let updated_at: String
}

struct PaymentEventInsert: Encodable {
    let payment_id: String
    let event_type: String        // "created","captured","failed","cod_confirmed", etc.
    let raw_payload: String?      // simple text or JSON string if needed
}
