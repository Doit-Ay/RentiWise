// NetworkMonitor.swift
// RentiWise
//
// Singleton that continuously watches network reachability using NWPathMonitor.
// Observers receive updates on the main thread via NotificationCenter.

import Foundation
import Network

final class NetworkMonitor {

    static let shared = NetworkMonitor()

    /// Posted on the main thread whenever connectivity changes.
    static let connectivityChangedNotification = Notification.Name("RW.NetworkMonitor.connectivityChanged")

    /// True when the device has a usable network path.
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue  = DispatchQueue(label: "rw.networkmonitor", qos: .utility)

    private init() {}

    /// Call once at app start (from SceneDelegate).
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            guard connected != self.isConnected else { return }   // no spurious pings
            self.isConnected = connected
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NetworkMonitor.connectivityChangedNotification,
                    object: nil,
                    userInfo: ["isConnected": connected]
                )
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
