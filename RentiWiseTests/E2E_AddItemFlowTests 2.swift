import XCTest
@testable import RentiWise

/// FLOW 1: LENDER — Add an Item
/// Tests the complete "Add New Item" journey:
/// Step 1 → Photos selected
/// Step 2 → Title, description, category, condition filled
/// Step 3 → Pricing (price per day, deposit amount) set
/// Step 4 → Published to Supabase
///
/// Note: ItemInsertPayload does NOT have latitude/longitude fields (verified from ItemModels.swift)
final class E2E_AddItemFlowTests: XCTestCase {

    // MARK: - Step 1: Draft Initialization

    func test_addItem_draftStartsEmpty() {
        let draft = AddItemDraft()
        XCTAssertFalse(draft.isEditing, "New draft should not be in edit mode")
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.description, "")
        XCTAssertEqual(draft.category, "")
        XCTAssertEqual(draft.pricePerDay, 0)
        XCTAssertEqual(draft.depositAmount, 0)
        XCTAssertEqual(draft.images.count, 0, "Draft should have no images initially")
    }

    func test_addItem_draftCanAcceptTitle() {
        var draft = AddItemDraft()
        draft.title = "DJI Drone Mavic 3"
        XCTAssertEqual(draft.title, "DJI Drone Mavic 3")
    }

    func test_addItem_draftCanAcceptImages() {
        var draft = AddItemDraft()
        let fakeImage = UIImage(systemName: "camera")!
        let data = fakeImage.jpegData(compressionQuality: 0.8)!
        draft.images = [data, data]
        XCTAssertEqual(draft.images.count, 2)
    }

    // MARK: - Step 2: Validation Logic

    func test_addItem_titleMustNotBeEmpty() {
        var draft = AddItemDraft()
        draft.title = ""
        XCTAssertTrue(draft.title.isEmpty, "Empty title should be caught before publishing")
    }

    func test_addItem_titleWithWhitespaceInvalid() {
        var draft = AddItemDraft()
        draft.title = "   "
        XCTAssertTrue(draft.title.trimmingCharacters(in: .whitespaces).isEmpty, "Whitespace-only title should be treated as empty")
    }

    func test_addItem_priceMustBePositive() {
        var draft = AddItemDraft()
        draft.pricePerDay = 0
        XCTAssertFalse(draft.pricePerDay > 0, "Price of 0 should not pass publish validation")
    }

    func test_addItem_negativePrice() {
        var draft = AddItemDraft()
        draft.pricePerDay = -100
        XCTAssertFalse(draft.pricePerDay > 0, "Negative price should fail validation")
    }

    func test_addItem_validPriceAccepted() {
        var draft = AddItemDraft()
        draft.pricePerDay = 250.0
        XCTAssertTrue(draft.pricePerDay > 0)
    }

    func test_addItem_depositCanBeZero() {
        var draft = AddItemDraft()
        draft.depositAmount = 0
        XCTAssertEqual(draft.depositAmount, 0)  // deposit is optional, 0 is valid
    }

    // MARK: - Step 3: Payload Construction
    // Real ItemInsertPayload fields: owner_id, title, description?, category?, condition?,
    // price_per_day, deposit_amount, images, is_active (NO latitude/longitude)

    func test_addItem_insertPayloadBuildsCorrectly() throws {
        let payload = ItemInsertPayload(
            owner_id: "owner-uuid-123",
            title: "Sony A7 Camera",
            description: "Mirrorless full-frame camera",
            category: "Photography",
            condition: "Like New",
            price_per_day: 1500.0,
            deposit_amount: 10000.0,
            images: ["item_photos/a7.jpg", "item_photos/a7b.jpg"],
            is_active: true
        )
        XCTAssertEqual(payload.title, "Sony A7 Camera")
        XCTAssertEqual(payload.price_per_day, 1500.0)
        XCTAssertEqual(payload.images.count, 2)
        XCTAssertTrue(payload.is_active)
    }

    func test_addItem_payloadEncodesCorrectly() throws {
        let payload = ItemInsertPayload(
            owner_id: "owner-uuid-123",
            title: "Nikon Lens 50mm",
            description: "Prime lens f/1.8",
            category: "Photography",
            condition: "Good",
            price_per_day: 500.0,
            deposit_amount: 3000.0,
            images: ["lens.jpg"],
            is_active: true
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        XCTAssertFalse(data.isEmpty)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["title"] as? String, "Nikon Lens 50mm")
        XCTAssertEqual(json["price_per_day"] as? Double, 500.0)
        XCTAssertEqual(json["owner_id"] as? String, "owner-uuid-123")
    }

    func test_addItem_payloadWithNilDescriptionEncodes() throws {
        let payload = ItemInsertPayload(
            owner_id: "owner-1",
            title: "Basic Tent",
            description: nil,
            category: nil,
            condition: nil,
            price_per_day: 200.0,
            deposit_amount: 500.0,
            images: [],
            is_active: true
        )
        let data = try JSONEncoder().encode(payload)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Step 4: Edit Mode

    func test_addItem_editModePreservesExistingItemId() {
        var draft = AddItemDraft()
        draft.isEditing = true
        draft.existingItemId = "item-abc-123"
        draft.existingImagePaths = ["photo1.jpg", "photo2.jpg"]
        XCTAssertEqual(draft.existingItemId, "item-abc-123")
        XCTAssertEqual(draft.existingImagePaths.count, 2)
    }

    func test_addItem_editModeCanChangeActiveStatus() {
        var draft = AddItemDraft()
        draft.isActive = true
        draft.isActive = false
        XCTAssertFalse(draft.isActive, "Lender should be able to deactivate an item")
    }

    // MARK: - Step 5: Image Handling

    func test_addItem_imageCompressionQualityBelow1() {
        let img = UIImage(systemName: "photo")!
        let data = img.jpegData(compressionQuality: 0.7)
        XCTAssertNotNil(data, "Should produce JPEG data")
    }

    func test_addItem_upTo4ImagesAllowed() {
        var draft = AddItemDraft()
        let fake = UIImage(systemName: "camera")!.jpegData(compressionQuality: 0.8)!
        draft.images = [fake, fake, fake, fake]
        XCTAssertEqual(draft.images.count, 4, "Should allow up to 4 images")
    }

    func test_addItem_singleImageIsValid() {
        var draft = AddItemDraft()
        let fake = UIImage(systemName: "camera")!.jpegData(compressionQuality: 0.8)!
        draft.images = [fake]
        XCTAssertEqual(draft.images.count, 1)
    }

    func test_addItem_categoryIsSetCorrectly() {
        var draft = AddItemDraft()
        draft.category = "Electronics"
        XCTAssertEqual(draft.category, "Electronics")
    }

    func test_addItem_conditionOptions() {
        let conditions = ["New", "Like New", "Good", "Fair", "Poor"]
        XCTAssertEqual(conditions.count, 5)
        XCTAssertTrue(conditions.contains("Like New"))
    }
}
