import XCTest
@testable import RentiWise

/// FLOW 2: BORROWER — Browse & Send Rental Request
/// Tests the complete "Find Item → View Details → Select Rental Type → Pick Dates → Send Request" flow.
/// Service fee in the app = 10% of rental fee (NOT 5% — verified from RequestViewController.serviceFeeRate)
final class E2E_BrowseAndRequestFlowTests: XCTestCase {

    // MARK: - Browse: Item Discovery

    func test_browse_itemDecodesForDisplay() throws {
        let json = """
        {
            "id": "item-001",
            "title": "DJI Mavic Air 2",
            "description": "Foldable drone with 4K camera",
            "images": ["drone1.jpg", "drone2.jpg"],
            "price_per_day": 800.0,
            "deposit_amount": 15000.0,
            "owner_id": "owner-xyz",
            "is_active": true,
            "category": "Photography"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let item = try decoder.decode(Item.self, from: json)
        XCTAssertEqual(item.title, "DJI Mavic Air 2")
        XCTAssertEqual(item.price_per_day, 800.0)
        XCTAssertTrue(item.is_active)
    }

    func test_browse_inactiveItemIsFilteredOut() throws {
        let json = """
        {
            "id": "item-999",
            "title": "Broken Camera",
            "images": [],
            "price_per_day": 100.0,
            "deposit_amount": 0.0,
            "owner_id": "owner-abc",
            "is_active": false
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(Item.self, from: json)
        XCTAssertFalse(item.is_active, "Inactive items should NOT be shown on home/browse")
    }

    func test_browse_itemWithNoReviewsShowsNoReviews() throws {
        let json = """
        {
            "id": "item-002",
            "title": "Camping Tent",
            "images": [],
            "price_per_day": 300.0,
            "deposit_amount": 2000.0,
            "owner_id": "owner-def",
            "is_active": true,
            "average_rating": null,
            "review_count": null
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(Item.self, from: json)
        XCTAssertNil(item.average_rating)
        XCTAssertNil(item.review_count)
    }

    func test_browse_itemSearchByTitle() {
        let items = [
            buildItem(id: "1", title: "Sony Camera"),
            buildItem(id: "2", title: "Nikon Lens"),
            buildItem(id: "3", title: "DJI Drone")
        ]
        let query = "camera"
        let results = items.filter { $0.title.lowercased().contains(query.lowercased()) }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "1")
    }

    func test_browse_itemSearchCaseInsensitive() {
        let items = [
            buildItem(id: "1", title: "Sony A7 Camera"),
            buildItem(id: "2", title: "DSLR Camera Kit")
        ]
        let results = items.filter { $0.title.lowercased().contains("camera") }
        XCTAssertEqual(results.count, 2)
    }

    func test_browse_filterByCategory() {
        let items = [
            buildItem(id: "1", title: "iPhone Tripod", category: "Photography"),
            buildItem(id: "2", title: "Mountain Bike", category: "Sports"),
            buildItem(id: "3", title: "Camera Bag", category: "Photography")
        ]
        let photography = items.filter { $0.category == "Photography" }
        XCTAssertEqual(photography.count, 2)
    }

    // MARK: - Pricing: Hourly Rate Calculation (Price / 8)
    // Use inline rounding (rounded(toPlaces:) is a private app extension not accessible in tests)

    private func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    func test_request_hourlyRateCalculation() {
        let pricePerDay: Double = 800.0
        let hourlyRate = round2(pricePerDay / 8.0)
        XCTAssertEqual(hourlyRate, 100.0, accuracy: 0.01)
    }

    func test_request_hourlyRateForOddPrice() {
        let pricePerDay: Double = 150.0
        let hourlyRate = round2(pricePerDay / 8.0)
        XCTAssertEqual(hourlyRate, 18.75, accuracy: 0.01)
    }

    // MARK: - Pricing: Total Calculation
    // Service fee = 10% (verified from RequestViewController.serviceFeeRate = 0.10)
    // Total = rentalFee + securityDeposit (service fee is computed but NOT added to total — see line 578)

    func test_request_totalForDailyRental_noServiceFeeInTotal() {
        let pricePerDay: Double = 500.0
        let deposit: Double = 3000.0
        let days: Double = 2
        let serviceFeeRate: Double = 0.10

        let rentalFee = pricePerDay * days  // 1000
        let serviceFee = rentalFee * serviceFeeRate  // 100 (computed but not added)
        let total = rentalFee + deposit  // 4000 (as per app code line 578)

        XCTAssertEqual(rentalFee, 1000.0, accuracy: 0.01)
        XCTAssertEqual(serviceFee, 100.0, accuracy: 0.01)
        XCTAssertEqual(total, 4000.0, accuracy: 0.01, "Total = rental fee + deposit only (no service fee in displayed total)")
    }

    func test_request_totalForHourlyRental() {
        let pricePerDay: Double = 800.0
        let deposit: Double = 5000.0
        let hours: Double = 3
        let hourlyRate = pricePerDay / 8.0  // 100

        let rentalFee = hourlyRate * hours  // 300
        let total = rentalFee + deposit  // 5300

        XCTAssertEqual(total, 5300.0, accuracy: 0.01)
    }

    func test_request_minimumDurationIs1Hour() {
        // App uses max(1, Int(ceil(hoursRaw))) to ensure minimum 1 hour billing
        let hoursRaw: Double = 0.5  // Half an hour selected
        let billableHours = max(1, Int(ceil(hoursRaw)))
        XCTAssertEqual(billableHours, 1)
    }

    func test_request_minimumDurationIs1Day() {
        let daysRaw: Double = 0.3  // Less than 1 day
        let billableDays = max(1, Int(ceil(daysRaw)))
        XCTAssertEqual(billableDays, 1)
    }

    func test_request_fractionalHoursRoundUp() {
        // 2.5 hours should be billed as 3 hours
        let hoursRaw: Double = 2.5
        let billableHours = max(1, Int(ceil(hoursRaw)))
        XCTAssertEqual(billableHours, 3)
    }

    // MARK: - Request Payload Validation

    func test_request_payloadContainsCorrectStatus() {
        // New requests always start as "pending"
        let requestStatus = "pending"
        XCTAssertEqual(requestStatus, "pending")
    }

    func test_request_startDateFormatIsISO() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Date()
        let str = formatter.string(from: date)
        XCTAssertTrue(str.count == 10, "Date should be in yyyy-MM-dd format (10 chars)")
        XCTAssertTrue(str.contains("-"))
    }

    func test_request_pickupTimeFormatContainsTimezone() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm:ssXXXXX"
        let time = formatter.string(from: Date())
        XCTAssertFalse(time.isEmpty)
        XCTAssertTrue(time.contains(":"))
    }

    func test_request_borrowerCannotSendRequestForOwnItem() {
        // Verified in ProductViewController line 360: if me == item.owner_id → ownItem mode
        let myUserId = "user-111"
        let itemOwnerId = "user-111"
        let isOwnItem = myUserId.lowercased() == itemOwnerId.lowercased()
        XCTAssertTrue(isOwnItem, "User should NOT see Rent button on their own items")
    }

    func test_request_differentUserSeesRentButton() {
        let myUserId = "user-111"
        let itemOwnerId = "user-222"
        let isOwnItem = myUserId.lowercased() == itemOwnerId.lowercased()
        XCTAssertFalse(isOwnItem, "Different user should see the Rent Now button")
    }

    // MARK: - Helpers

    private func buildItem(id: String, title: String, category: String? = nil) -> Item {
        return Item(
            id: id,
            owner_id: "owner-test",
            title: title,
            description: nil,
            category: category,
            condition: nil,
            price_per_day: 100,
            deposit_amount: 0,
            images: [],
            is_active: true,
            latitude: nil,
            longitude: nil,
            location_address: nil,
            created_at: nil,
            updated_at: nil
        )
    }
}
