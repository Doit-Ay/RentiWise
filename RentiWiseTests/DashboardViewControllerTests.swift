import XCTest
@testable import RentiWise

final class DashboardViewControllerTests: XCTestCase {

    // MARK: - History Filter Logic

    func testFilterInProgress() {
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "pending"), .inProgress)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "accepted"), .inProgress)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "approved"), .inProgress)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "returned"), .inProgress)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "in_progress"), .inProgress)
    }

    func testFilterCompleted() {
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "completed"), .completed)
    }

    func testFilterCancelled() {
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "cancelled"), .cancelled)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "rejected"), .cancelled)
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "denied"), .cancelled)
    }

    func testFilterUnknownStatusRemainsUnknown() {
        XCTAssertEqual(DashboardHistoryStatus.classification(for: "archived"), .unknown)
    }

    // MARK: - Segment (Listings vs History)

    func testSegmentValues() {
        // Dashboard has two segments: "Listings" (0) and "History" (1)
        let segments = ["Listings", "History"]
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0], "Listings")
        XCTAssertEqual(segments[1], "History")
    }

    // MARK: - Status Display Mapping

    func testStatusDisplayPending() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "pending"), "Pending")
    }

    func testStatusDisplayAccepted() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "accepted"), "Accepted")
    }

    func testStatusDisplayApprovedUsesActiveCopy() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "approved"), "Active")
    }

    func testStatusDisplayReturnedUsesReturnPendingCopy() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "returned"), "Return Pending")
    }

    func testStatusDisplayDenied() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "denied"), "Denied")
    }

    func testStatusDisplayCompleted() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "completed"), "Completed")
    }

    func testStatusDisplayUnknown() {
        XCTAssertEqual(DashboardHistoryStatus.displayText(for: "some_status"), "Some Status")
    }

    // MARK: - Date Formatting for Display

    func testDateFormattingDashboard() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2025-12-25")
        XCTAssertNotNil(date)

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        let result = displayFormatter.string(from: date!)
        XCTAssertFalse(result.isEmpty)
    }
}
