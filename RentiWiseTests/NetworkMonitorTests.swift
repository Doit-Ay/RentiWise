import XCTest
@testable import RentiWise

final class NetworkMonitorTests: XCTestCase {

    func testSharedInstanceExists() {
        let monitor = NetworkMonitor.shared
        XCTAssertNotNil(monitor)
    }

    func testSharedInstanceIsSingleton() {
        let m1 = NetworkMonitor.shared
        let m2 = NetworkMonitor.shared
        XCTAssertTrue(m1 === m2)
    }

    func testInitialConnectedState() {
        // Default isConnected should be true before monitoring starts
        let monitor = NetworkMonitor.shared
        XCTAssertTrue(monitor.isConnected)
    }

    func testNotificationNameConstant() {
        let expected = Notification.Name("RW.NetworkMonitor.connectivityChanged")
        XCTAssertEqual(NetworkMonitor.connectivityChangedNotification, expected)
    }

    func testNotificationNameNotEmpty() {
        XCTAssertFalse(NetworkMonitor.connectivityChangedNotification.rawValue.isEmpty)
    }
}
