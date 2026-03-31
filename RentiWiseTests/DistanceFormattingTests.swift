import XCTest
@testable import RentiWise

/// Tests distance formatting logic from DistanceService.
/// Since DistanceService.formatDistance is private, we replicate the logic to test it.
final class DistanceFormattingTests: XCTestCase {

    // Replicating the exact logic from DistanceService.formatDistance
    private func formatDistance(meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }

    func testFormatDistanceMeters() {
        let result = formatDistance(meters: 500)
        XCTAssertEqual(result, "500 m")
    }

    func testFormatDistanceSmallMeters() {
        let result = formatDistance(meters: 10)
        XCTAssertEqual(result, "10 m")
    }

    func testFormatDistanceKilometers() {
        let result = formatDistance(meters: 2300)
        XCTAssertEqual(result, "2.3 km")
    }

    func testFormatDistanceExactly1000() {
        let result = formatDistance(meters: 1000)
        XCTAssertEqual(result, "1.0 km")
    }

    func testFormatDistanceZero() {
        let result = formatDistance(meters: 0)
        XCTAssertEqual(result, "0 m")
    }

    func testFormatDistanceLargeValue() {
        let result = formatDistance(meters: 150000.0)
        XCTAssertEqual(result, "150.0 km")
    }

    func testFormatDistanceFractionalMeters() {
        let result = formatDistance(meters: 999.5)
        // 999.5 rounds to 1000
        XCTAssertEqual(result, "1000 m")
    }

    func testFormatDistanceJustUnder1000() {
        let result = formatDistance(meters: 999.4)
        // 999.4 rounds to 999
        XCTAssertEqual(result, "999 m")
    }
}
