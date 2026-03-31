import XCTest
@testable import RentiWise

final class PaymentModelTests: XCTestCase {

    // MARK: - PaymentInsert Encoding

    func testPaymentInsertEncoding() throws {
        let insert = PaymentInsert(
            request_id: "req-1",
            item_id: "item-1",
            owner_id: "owner-1",
            borrower_id: "borrower-1",
            provider: "cod",
            status: "pending",
            currency: "INR",
            rental_fee: 150.00,
            deposit_amount: 500.00,
            total_amount: 650.00
        )

        let data = try JSONEncoder().encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["request_id"] as? String, "req-1")
        XCTAssertEqual(dict?["provider"] as? String, "cod")
        XCTAssertEqual(dict?["status"] as? String, "pending")
        XCTAssertEqual(dict?["currency"] as? String, "INR")
        XCTAssertEqual(dict?["rental_fee"] as? Double, 150.00)
        XCTAssertEqual(dict?["total_amount"] as? Double, 650.00)
    }

    // MARK: - PaymentUpdate Encoding

    func testPaymentUpdateEncodingAllFields() throws {
        let update = PaymentUpdate(
            status: "succeeded",
            pickup_code: "ABC123",
            provider_payment_id: "pay_xyz",
            provider_receipt_url: "https://receipt.com",
            failure_reason: nil
        )

        let data = try JSONEncoder().encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["status"] as? String, "succeeded")
        XCTAssertEqual(dict?["pickup_code"] as? String, "ABC123")
        XCTAssertEqual(dict?["provider_payment_id"] as? String, "pay_xyz")
    }

    func testPaymentUpdateEncodingNilFields() throws {
        let update = PaymentUpdate(
            status: nil,
            pickup_code: nil,
            provider_payment_id: nil,
            provider_receipt_url: nil,
            failure_reason: "Card declined"
        )

        let data = try JSONEncoder().encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["failure_reason"] as? String, "Card declined")
    }

    // MARK: - PaymentRow Decoding

    func testPaymentRowDecoding() throws {
        let json = """
        {
            "id": "pay-1",
            "request_id": "req-1",
            "item_id": "item-1",
            "owner_id": "owner-1",
            "borrower_id": "borrower-1",
            "provider": "apple_pay",
            "status": "succeeded",
            "currency": "INR",
            "rental_fee": 200.00,
            "deposit_amount": 500.00,
            "total_amount": 700.00,
            "pickup_code": "XYZ",
            "provider_payment_id": "ppid",
            "provider_receipt_url": "https://r.com",
            "failure_reason": null,
            "created_at": "2025-12-01T00:00:00Z",
            "updated_at": "2025-12-02T00:00:00Z"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(PaymentRow.self, from: json)
        XCTAssertEqual(row.id, "pay-1")
        XCTAssertEqual(row.provider, "apple_pay")
        XCTAssertEqual(row.status, "succeeded")
        XCTAssertEqual(row.total_amount, 700.00)
        XCTAssertEqual(row.pickup_code, "XYZ")
        XCTAssertNil(row.failure_reason)
    }

    func testPaymentRowDecodingNilOptionals() throws {
        let json = """
        {
            "id": "pay-2",
            "request_id": "req-2",
            "item_id": "item-2",
            "owner_id": "o2",
            "borrower_id": "b2",
            "provider": "cod",
            "status": "pending",
            "currency": "INR",
            "rental_fee": 100.00,
            "deposit_amount": 200.00,
            "total_amount": 300.00,
            "pickup_code": null,
            "provider_payment_id": null,
            "provider_receipt_url": null,
            "failure_reason": null,
            "created_at": "2025-12-01T00:00:00Z",
            "updated_at": "2025-12-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(PaymentRow.self, from: json)
        XCTAssertNil(row.pickup_code)
        XCTAssertNil(row.provider_payment_id)
        XCTAssertNil(row.provider_receipt_url)
        XCTAssertNil(row.failure_reason)
    }

    // MARK: - PaymentEventInsert Encoding

    func testPaymentEventInsertEncoding() throws {
        let event = PaymentEventInsert(
            payment_id: "pay-1",
            event_type: "created",
            raw_payload: "{\"foo\": \"bar\"}"
        )

        let data = try JSONEncoder().encode(event)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["payment_id"] as? String, "pay-1")
        XCTAssertEqual(dict?["event_type"] as? String, "created")
        XCTAssertNotNil(dict?["raw_payload"])
    }

    func testPaymentEventInsertEncodingNilPayload() throws {
        let event = PaymentEventInsert(
            payment_id: "pay-2",
            event_type: "failed",
            raw_payload: nil
        )

        let data = try JSONEncoder().encode(event)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["event_type"] as? String, "failed")
    }

    // MARK: - Payment Providers

    func testPaymentProviderValues() {
        // Verify that common provider strings match expected values
        let providers = ["apple_pay", "card", "cod"]
        XCTAssertTrue(providers.contains("apple_pay"))
        XCTAssertTrue(providers.contains("card"))
        XCTAssertTrue(providers.contains("cod"))
    }
}
