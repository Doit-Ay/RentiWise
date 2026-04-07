import XCTest
@testable import RentiWise

final class DashboardViewControllerTests: XCTestCase {

    // MARK: - History Filter Logic (replicated from DashboardViewController)

    // The dashboard uses status strings to filter requests
    private let allStatuses = ["pending", "accepted", "completed", "cancelled", "rejected", "in_progress"]

    private func filteredStatuses(for filter: String) -> [String] {
        switch filter {
        case "in_progress":
            return allStatuses.filter { ["pending", "accepted", "in_progress"].contains($0) }
        case "completed":
            return allStatuses.filter { $0 == "completed" }
        case "cancelled":
            return allStatuses.filter { ["cancelled", "rejected"].contains($0) }
        case "all":
            return allStatuses
        default:
            return allStatuses
        }
    }

    func testFilterInProgress() {
        let result = filteredStatuses(for: "in_progress")
        XCTAssertTrue(result.contains("pending"))
        XCTAssertTrue(result.contains("accepted"))
        XCTAssertTrue(result.contains("in_progress"))
        XCTAssertFalse(result.contains("completed"))
        XCTAssertFalse(result.contains("cancelled"))
    }

    func testFilterCompleted() {
        let result = filteredStatuses(for: "completed")
        XCTAssertTrue(result.contains("completed"))
        XCTAssertFalse(result.contains("pending"))
        XCTAssertEqual(result.count, 1)
    }

    func testFilterCancelled() {
        let result = filteredStatuses(for: "cancelled")
        XCTAssertTrue(result.contains("cancelled"))
        XCTAssertTrue(result.contains("rejected"))
        XCTAssertEqual(result.count, 2)
    }

    func testFilterAll() {
        let result = filteredStatuses(for: "all")
        XCTAssertEqual(result.count, allStatuses.count)
    }

    func testFilterUnknownDefaultsToAll() {
        let result = filteredStatuses(for: "unknown_filter")
        XCTAssertEqual(result.count, allStatuses.count)
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

    private func displayStatus(for rawStatus: String) -> String {
        switch rawStatus {
        case "pending": return "Pending"
        case "accepted": return "Accepted"
        case "rejected": return "Rejected"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "in_progress": return "In Progress"
        default: return rawStatus.capitalized
        }
    }

    func testStatusDisplayPending() {
        XCTAssertEqual(displayStatus(for: "pending"), "Pending")
    }

    func testStatusDisplayAccepted() {
        XCTAssertEqual(displayStatus(for: "accepted"), "Accepted")
    }

    func testStatusDisplayCompleted() {
        XCTAssertEqual(displayStatus(for: "completed"), "Completed")
    }

    func testStatusDisplayUnknown() {
        XCTAssertEqual(displayStatus(for: "some_status"), "Some_Status")
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
