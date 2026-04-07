import XCTest
@testable import RentiWise

final class ItemModelTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Item Decoding

    func testItemDecodingAllFields() throws {
        let json = """
        {
            "id": "abc-123",
            "owner_id": "user-1",
            "title": "Drone DJI",
            "description": "A nice drone",
            "category": "Electronics",
            "condition": "Like New",
            "price_per_day": 150.00,
            "deposit_amount": 500.00,
            "images": ["path/img1.jpg", "path/img2.jpg"],
            "is_active": true,
            "latitude": 12.82,
            "longitude": 80.04,
            "location_address": "Chennai",
            "created_at": "2025-12-01T00:00:00Z",
            "updated_at": "2025-12-02T00:00:00Z",
            "average_rating": 4.5,
            "review_count": 10
        }
        """.data(using: .utf8)!

        let item = try makeDecoder().decode(Item.self, from: json)

        XCTAssertEqual(item.id, "abc-123")
        XCTAssertEqual(item.owner_id, "user-1")
        XCTAssertEqual(item.title, "Drone DJI")
        XCTAssertEqual(item.description, "A nice drone")
        XCTAssertEqual(item.category, "Electronics")
        XCTAssertEqual(item.condition, "Like New")
        XCTAssertEqual(item.price_per_day, 150.00)
        XCTAssertEqual(item.deposit_amount, 500.00)
        XCTAssertEqual(item.images.count, 2)
        XCTAssertTrue(item.is_active)
        XCTAssertEqual(item.latitude, 12.82)
        XCTAssertEqual(item.longitude, 80.04)
        XCTAssertEqual(item.location_address, "Chennai")
        XCTAssertEqual(item.average_rating, 4.5)
        XCTAssertEqual(item.review_count, 10)
    }

    func testItemDecodingOptionalFieldsNil() throws {
        let json = """
        {
            "id": "abc-456",
            "owner_id": "user-2",
            "title": "Camera",
            "description": null,
            "category": null,
            "condition": null,
            "price_per_day": 100.00,
            "deposit_amount": 200.00,
            "images": [],
            "is_active": false,
            "created_at": null,
            "updated_at": null
        }
        """.data(using: .utf8)!

        let item = try makeDecoder().decode(Item.self, from: json)

        XCTAssertEqual(item.id, "abc-456")
        XCTAssertNil(item.description)
        XCTAssertNil(item.category)
        XCTAssertNil(item.condition)
        XCTAssertTrue(item.images.isEmpty)
        XCTAssertFalse(item.is_active)
        XCTAssertNil(item.created_at)
        XCTAssertNil(item.updated_at)
        XCTAssertNil(item.average_rating)
        XCTAssertNil(item.review_count)
        XCTAssertNil(item.latitude)
        XCTAssertNil(item.longitude)
    }

    func testItemDecodingMissingRequiredFieldsFails() {
        let json = """
        {
            "id": "abc",
            "title": "Test"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try makeDecoder().decode(Item.self, from: json))
    }

    func testItemMemberwiseInitializer() {
        let item = Item(
            id: "test-id",
            owner_id: "owner-1",
            title: "Test Item",
            description: "Desc",
            category: "Tools",
            condition: "Good",
            price_per_day: 50.0,
            deposit_amount: 100.0,
            images: ["img.jpg"],
            is_active: true,
            created_at: Date(),
            updated_at: Date(),
            average_rating: 3.5,
            review_count: 5
        )

        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.title, "Test Item")
        XCTAssertEqual(item.price_per_day, 50.0)
        XCTAssertEqual(item.average_rating, 3.5)
    }

    func testItemDecodingEmptyImages() throws {
        let json = """
        {
            "id": "x",
            "owner_id": "o",
            "title": "T",
            "price_per_day": 10.0,
            "deposit_amount": 0.0,
            "images": [],
            "is_active": true
        }
        """.data(using: .utf8)!

        let item = try makeDecoder().decode(Item.self, from: json)
        XCTAssertTrue(item.images.isEmpty)
    }

    // MARK: - ItemRow Decoding

    func testItemRowDecoding() throws {
        let json = """
        {
            "id": "row-1",
            "owner_id": "owner-1",
            "title": "Tent",
            "description": null,
            "category": "Outdoor",
            "condition": "New",
            "price_per_day": 75.50,
            "deposit_amount": 200.00,
            "images": ["tent.jpg"],
            "is_active": true,
            "created_at": "2025-12-01T00:00:00Z",
            "updated_at": "2025-12-02T00:00:00Z"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(ItemRow.self, from: json)
        XCTAssertEqual(row.id, "row-1")
        XCTAssertEqual(row.title, "Tent")
        XCTAssertEqual(row.price_per_day, 75.50)
    }

    // MARK: - ItemInsertPayload Encoding

    func testItemInsertPayloadEncoding() throws {
        let payload = ItemInsertPayload(
            owner_id: "owner-1",
            title: "Speaker",
            description: "Bluetooth",
            category: "Electronics",
            condition: "Good",
            price_per_day: 30.0,
            deposit_amount: 50.0,
            declared_value: 2500,
            images: ["speaker.jpg"],
            is_active: true,
            latitude: nil,
            longitude: nil,
            location_address: nil
        )

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["title"] as? String, "Speaker")
        XCTAssertEqual(dict?["price_per_day"] as? Double, 30.0)
        XCTAssertEqual(dict?["declared_value"] as? Int, 2500)
        XCTAssertEqual(dict?["is_active"] as? Bool, true)
    }

    // MARK: - AddItemDraft Defaults

    func testAddItemDraftDefaults() {
        let draft = AddItemDraft()
        XCTAssertTrue(draft.images.isEmpty)
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.description, "")
        XCTAssertEqual(draft.category, "")
        XCTAssertEqual(draft.condition, "")
        XCTAssertEqual(draft.pricePerDay, 0)
        XCTAssertEqual(draft.depositAmount, 0)
        XCTAssertTrue(draft.isActive)
        XCTAssertFalse(draft.isEditing)
        XCTAssertNil(draft.existingItemId)
        XCTAssertTrue(draft.existingImagePaths.isEmpty)
    }

    func testAddItemDraftEditMode() {
        var draft = AddItemDraft()
        draft.isEditing = true
        draft.existingItemId = "old-item-id"
        draft.existingImagePaths = ["img1.jpg"]

        XCTAssertTrue(draft.isEditing)
        XCTAssertEqual(draft.existingItemId, "old-item-id")
        XCTAssertEqual(draft.existingImagePaths.count, 1)
    }

    func testItemDecodingZeroPrices() throws {
        let json = """
        {
            "id": "z",
            "owner_id": "o",
            "title": "Free Item",
            "price_per_day": 0.0,
            "deposit_amount": 0.0,
            "images": [],
            "is_active": true
        }
        """.data(using: .utf8)!

        let item = try makeDecoder().decode(Item.self, from: json)
        XCTAssertEqual(item.price_per_day, 0.0)
        XCTAssertEqual(item.deposit_amount, 0.0)
    }
}
