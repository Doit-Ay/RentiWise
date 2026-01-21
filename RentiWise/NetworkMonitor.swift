import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    private(set) var isConnected: Bool = true

    private init() {
        monitor = NWPathMonitor()
        // Initialize with current path status once the monitor starts.
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = (path.status == .satisfied)

            // Only notify when the value actually changes
            if self.isConnected != connected {
                self.isConnected = connected
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .networkConnectivityChanged, object: self)
                }
            } else {
                self.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("NetworkConnectivityChangedNotification")
}
