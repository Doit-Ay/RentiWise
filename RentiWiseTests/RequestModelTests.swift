import XCTest
@testable import RentiWise

final class RequestModelTests: XCTestCase {

    // MARK: - RequestWithItem Decoding

    func testRequestWithItemDecodingFull() throws {
        let json = """
        {
            "id": "req-1",
            "item_id": "item-1",
            "owner_id": "owner-1",
            "borrower_id": "borrower-1",
            "start_date": "2025-12-01",
            "end_date": "2025-12-05",
            "pickup_time": "10:00:00+05:30",
            "status": "pending",
            "created_at": "2025-12-01T00:00:00Z",
            "items": {
                "id": "item-1",
                "title": "Drone",
                "images": ["drone.jpg"],
                "price_per_day": 100.0,
                "category": "Electronics"
            }
        }
        """.data(using: .utf8)!

        let req = try JSONDecoder().decode(RequestWithItem.self, from: json)
        XCTAssertEqual(req.id, "req-1")
        XCTAssertEqual(req.item_id, "item-1")
        XCTAssertEqual(req.owner_id, "owner-1")
        XCTAssertEqual(req.borrower_id, "borrower-1")
        XCTAssertEqual(req.start_date, "2025-12-01")
        XCTAssertEqual(req.end_date, "2025-12-05")
        XCTAssertEqual(req.status, "pending")
        XCTAssertNotNil(req.items)
        XCTAssertEqual(req.items?.title, "Drone")
        XCTAssertEqual(req.items?.price_per_day, 100.0)
        XCTAssertEqual(req.items?.category, "Electronics")
    }

    func testRequestWithItemDecodingNilItem() throws {
        let json = """
        {
            "id": "req-2",
            "item_id": "item-2",
            "owner_id": "owner-2",
            "borrower_id": "borrower-2",
            "start_date": "2025-12-10",
            "end_date": "2025-12-12",
            "pickup_time": null,
            "status": "accepted",
            "created_at": null,
            "items": null
        }
        """.data(using: .utf8)!

        let req = try JSONDecoder().decode(RequestWithItem.self, from: json)
        XCTAssertNil(req.items)
        XCTAssertNil(req.pickup_time)
        XCTAssertNil(req.created_at)
        XCTAssertEqual(req.status, "accepted")
    }

    func testRequestStatusMutability() throws {
        let json = """
        {
            "id": "req-3",
            "item_id": "i",
            "owner_id": "o",
            "borrower_id": "b",
            "start_date": "2025-12-01",
            "end_date": "2025-12-02",
            "status": "pending",
            "created_at": null
        }
        """.data(using: .utf8)!

        var req = try JSONDecoder().decode(RequestWithItem.self, from: json)
        XCTAssertEqual(req.status, "pending")
        req.status = "accepted"
        XCTAssertEqual(req.status, "accepted")
    }

    // MARK: - ItemLite Decoding

    func testItemLiteDecoding() throws {
        let json = """
        {
            "id": "il-1",
            "title": "Speaker",
            "images": ["spk1.jpg", "spk2.jpg"],
            "price_per_day": 50.0,
            "category": "Events"
        }
        """.data(using: .utf8)!

        let itemLite = try JSONDecoder().decode(ItemLite.self, from: json)
        XCTAssertEqual(itemLite.id, "il-1")
        XCTAssertEqual(itemLite.title, "Speaker")
        XCTAssertEqual(itemLite.images.count, 2)
        XCTAssertEqual(itemLite.price_per_day, 50.0)
        XCTAssertEqual(itemLite.category, "Events")
    }

    func testItemLiteDecodingNilCategory() throws {
        let json = """
        {
            "id": "il-2",
            "title": "Tent",
            "images": [],
            "price_per_day": 75.0,
            "category": null
        }
        """.data(using: .utf8)!

        let itemLite = try JSONDecoder().decode(ItemLite.self, from: json)
        XCTAssertNil(itemLite.category)
        XCTAssertTrue(itemLite.images.isEmpty)
    }

    func testItemLiteDecodingMissingImagesDefaultsToEmptyArray() throws {
        let json = """
        {
            "id": "il-3",
            "title": "Projector",
            "price_per_day": 150.0,
            "category": "Electronics"
        }
        """.data(using: .utf8)!

        let itemLite = try JSONDecoder().decode(ItemLite.self, from: json)
        XCTAssertEqual(itemLite.id, "il-3")
        XCTAssertTrue(itemLite.images.isEmpty)
        XCTAssertEqual(itemLite.category, "Electronics")
    }
}
