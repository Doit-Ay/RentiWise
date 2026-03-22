import XCTest
@testable import RentiWise

/// Tests pricing logic extracted from RequestViewController.
/// The app uses: hourlyRate = pricePerDay / 8, and computes totals.
final class PricingLogicTests: XCTestCase {

    // Helper replicating the exact logic from RequestViewController
    private func calculateHourlyRate(pricePerDay: Double) -> Double {
        return pricePerDay / 8.0
    }

    private func calculateTotal(
        pricePerDay: Double,
        isHourly: Bool,
        quantity: Int,  // hours or days
        depositAmount: Double
    ) -> (rentalFee: Double, serviceFee: Double, depositAmount: Double, total: Double) {
        let unitRate = isHourly ? calculateHourlyRate(pricePerDay: pricePerDay) : pricePerDay
        let rentalFee = unitRate * Double(quantity)
        let serviceFee = rentalFee * 0.05  // 5% service fee
        let total = rentalFee + serviceFee + depositAmount
        return (rentalFee, serviceFee, depositAmount, total)
    }

    // MARK: - Hourly Rate

    func testHourlyRateFromDailyPrice() {
        let rate = calculateHourlyRate(pricePerDay: 160.0)
        XCTAssertEqual(rate, 20.0, accuracy: 0.01)
    }

    func testHourlyRateFromSmallDailyPrice() {
        let rate = calculateHourlyRate(pricePerDay: 8.0)
        XCTAssertEqual(rate, 1.0, accuracy: 0.01)
    }

    func testHourlyRateZero() {
        let rate = calculateHourlyRate(pricePerDay: 0.0)
        XCTAssertEqual(rate, 0.0, accuracy: 0.01)
    }

    // MARK: - Daily Pricing

    func testDailyPricingSingleDay() {
        let result = calculateTotal(pricePerDay: 100.0, isHourly: false, quantity: 1, depositAmount: 500.0)
        XCTAssertEqual(result.rentalFee, 100.0, accuracy: 0.01)
        XCTAssertEqual(result.serviceFee, 5.0, accuracy: 0.01)
        XCTAssertEqual(result.total, 605.0, accuracy: 0.01) // 100 + 5 + 500
    }

    func testDailyPricingMultiDay() {
        let result = calculateTotal(pricePerDay: 100.0, isHourly: false, quantity: 5, depositAmount: 200.0)
        XCTAssertEqual(result.rentalFee, 500.0, accuracy: 0.01)
        XCTAssertEqual(result.serviceFee, 25.0, accuracy: 0.01)
        XCTAssertEqual(result.total, 725.0, accuracy: 0.01) // 500 + 25 + 200
    }

    // MARK: - Hourly Pricing

    func testHourlyPricingSingleHour() {
        let result = calculateTotal(pricePerDay: 80.0, isHourly: true, quantity: 1, depositAmount: 100.0)
        let expectedHourly = 80.0 / 8.0 // 10.0
        XCTAssertEqual(result.rentalFee, expectedHourly, accuracy: 0.01)
        XCTAssertEqual(result.total, expectedHourly + (expectedHourly * 0.05) + 100.0, accuracy: 0.01)
    }

    func testHourlyPricingMultiHour() {
        let result = calculateTotal(pricePerDay: 80.0, isHourly: true, quantity: 4, depositAmount: 50.0)
        let expectedRental = (80.0 / 8.0) * 4.0 // 40.0
        XCTAssertEqual(result.rentalFee, expectedRental, accuracy: 0.01)
        XCTAssertEqual(result.serviceFee, expectedRental * 0.05, accuracy: 0.01)
    }

    // MARK: - Service Fee

    func testServiceFeePercentage() {
        let result = calculateTotal(pricePerDay: 200.0, isHourly: false, quantity: 1, depositAmount: 0)
        // 5% of 200 = 10
        XCTAssertEqual(result.serviceFee, 10.0, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testZeroQuantity() {
        let result = calculateTotal(pricePerDay: 100.0, isHourly: false, quantity: 0, depositAmount: 500.0)
        XCTAssertEqual(result.rentalFee, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.total, 500.0, accuracy: 0.01)  // only deposit
    }

    func testZeroDeposit() {
        let result = calculateTotal(pricePerDay: 100.0, isHourly: false, quantity: 1, depositAmount: 0)
        XCTAssertEqual(result.total, 105.0, accuracy: 0.01) // 100 + 5 (service fee)
    }

    func testLargePricing() {
        let result = calculateTotal(pricePerDay: 10000.0, isHourly: false, quantity: 30, depositAmount: 50000.0)
        XCTAssertEqual(result.rentalFee, 300000.0, accuracy: 0.01)
        XCTAssertEqual(result.serviceFee, 15000.0, accuracy: 0.01)
        XCTAssertEqual(result.total, 365000.0, accuracy: 0.01)
    }

    func testFractionalPricing() {
        let result = calculateTotal(pricePerDay: 99.99, isHourly: false, quantity: 3, depositAmount: 150.0)
        let expectedRental = 99.99 * 3.0
        XCTAssertEqual(result.rentalFee, expectedRental, accuracy: 0.01)
    }
}
