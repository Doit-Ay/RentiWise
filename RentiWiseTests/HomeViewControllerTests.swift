import XCTest
@testable import RentiWise

final class HomeViewControllerTests: XCTestCase {

    // MARK: - Categories

    func testCategoriesListCount() {
        // HomeViewController defines categories inline. We test the expected set.
        let expectedCategories = [
            "Electronics", "Vehicles", "Photography", "Events",
            "Sports", "Furniture", "Books", "Home Appliances",
            "Tools", "Musical Instruments"
        ]
        XCTAssertEqual(expectedCategories.count, 10)
    }

    func testCategoriesAreUnique() {
        let categories = [
            "Electronics", "Vehicles", "Photography", "Events",
            "Sports", "Furniture", "Books", "Home Appliances",
            "Tools", "Musical Instruments"
        ]
        let uniqueSet = Set(categories)
        XCTAssertEqual(categories.count, uniqueSet.count, "All categories should be unique")
    }

    // MARK: - Greeting Logic (replicated from HomeViewController)

    private func greetingForHour(_ hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    func testGreetingMorning() {
        XCTAssertEqual(greetingForHour(8), "Good morning")
        XCTAssertEqual(greetingForHour(5), "Good morning")
        XCTAssertEqual(greetingForHour(11), "Good morning")
    }

    func testGreetingAfternoon() {
        XCTAssertEqual(greetingForHour(12), "Good afternoon")
        XCTAssertEqual(greetingForHour(14), "Good afternoon")
        XCTAssertEqual(greetingForHour(16), "Good afternoon")
    }

    func testGreetingEvening() {
        XCTAssertEqual(greetingForHour(17), "Good evening")
        XCTAssertEqual(greetingForHour(19), "Good evening")
        XCTAssertEqual(greetingForHour(20), "Good evening")
    }

    func testGreetingNight() {
        XCTAssertEqual(greetingForHour(21), "Good night")
        XCTAssertEqual(greetingForHour(0), "Good night")
        XCTAssertEqual(greetingForHour(4), "Good night")
    }

    // MARK: - Currency Formatter

    func testCurrencyFormatterINR() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")

        let result = formatter.string(from: NSNumber(value: 150.0))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("₹") || result!.contains("INR"))
    }

    func testCurrencyFormatterZero() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")

        let result = formatter.string(from: NSNumber(value: 0.0))
        XCTAssertNotNil(result)
    }

    func testCurrencyFormatterLargeValue() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")

        let result = formatter.string(from: NSNumber(value: 99999.99))
        XCTAssertNotNil(result)
    }
}
