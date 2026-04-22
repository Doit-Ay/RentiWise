//
//  AppLocationManager.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import Foundation
import CoreLocation

/// Modern Core Location wrapper using CLServiceSession + CLLocationUpdate (iOS 17+).
///
/// Replaces the legacy delegate-based CLLocationManager approach to avoid
/// main-thread blocking warnings in iOS 26. Uses pure async/await.
final class AppLocationManager: NSObject {

    static let shared = AppLocationManager()

    /// Holds the service session alive while we need location access.
    /// Created on first authorization request, invalidated if denied.
    private var serviceSession: CLServiceSession?

    /// Legacy manager — only used for reading `authorizationStatus`.
    private let manager = CLLocationManager()

    private let geocoder = CLGeocoder()

    /// The last successfully fetched GPS location. Cached so repeated calls
    /// don't all need a fresh GPS fix.
    private(set) var lastKnownLocation: CLLocation?

    /// How long to wait for a GPS fix before timing out.
    private let locationTimeout: TimeInterval = 10.0

    private override init() {
        super.init()
    }

    // MARK: - Error types

    enum LocationError: Error {
        case permissionDenied
        case servicesDisabled
        case failed
        case timedOut
        case reverseGeocodeFailed
    }

    // MARK: - Authorization

    /// Whether the user has already granted location permission (When-In-Use or Always).
    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// The current Core Location authorization status.
    var currentAuthorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// Ensures When-In-Use authorization. Uses CLServiceSession (iOS 18+) which
    /// handles the prompt lifecycle automatically and does NOT block the main thread.
    func ensureWhenInUseAuthorization() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.servicesDisabled
        }

        // If already authorized, nothing to do
        if isAuthorized { return }

        // If denied/restricted, throw immediately
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocationError.permissionDenied
        }

        // Status is .notDetermined — create a service session to trigger the prompt
        serviceSession = CLServiceSession(authorization: .whenInUse)

        // Wait for the authorization to resolve (up to 30 seconds for user to respond)
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
            let currentStatus = manager.authorizationStatus
            if currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways {
                return
            }
            if currentStatus == .denied || currentStatus == .restricted {
                serviceSession?.invalidate()
                serviceSession = nil
                throw LocationError.permissionDenied
            }
        }

        // Timed out waiting for user to respond
        throw LocationError.timedOut
    }

    // MARK: - Location fetching

    /// Returns the device's current coordinates, or nil if unavailable.
    /// Does NOT prompt for permission — returns nil if not authorized.
    func currentCoordinates() async -> CLLocationCoordinate2D? {
        guard isAuthorized else { return nil }

        // If we have a recent cached location (< 30 seconds old), use it
        if let cached = lastKnownLocation,
           abs(cached.timestamp.timeIntervalSinceNow) < 30 {
            debugLog("[AppLocationManager] Returning cached coordinate: \(cached.coordinate.latitude), \(cached.coordinate.longitude)")
            return cached.coordinate
        }

        do {
            let loc = try await fetchLocationWithLiveUpdates()
            return loc.coordinate
        } catch {
            debugLog("[AppLocationManager] currentCoordinates() failed: \(error)")
            return nil
        }
    }

    /// One-shot current location (ensures authorization first).
    /// Uses CLLocationUpdate.liveUpdates() — fully async, no main thread blocking.
    func currentLocation() async throws -> CLLocation {
        try await ensureWhenInUseAuthorization()
        return try await fetchLocationWithLiveUpdates()
    }

    /// Internal: fetch location using the modern CLLocationUpdate async sequence.
    /// Gets the first valid location update and returns it.
    private func fetchLocationWithLiveUpdates() async throws -> CLLocation {
        debugLog("[AppLocationManager] Starting GPS fetch via CLLocationUpdate.liveUpdates()...")

        // Ensure we have a service session active
        if serviceSession == nil {
            serviceSession = CLServiceSession(authorization: .whenInUse)
        }

        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            // Task 1: Listen for location updates
            group.addTask {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    if let location = update.location {
                        // Reject wildly inaccurate locations (> 1000m uncertainty)
                        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 1000 {
                            debugLog("[AppLocationManager] ✅ GPS fix: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
                            return location
                        } else {
                            debugLog("[AppLocationManager] Skipping inaccurate fix (accuracy: \(location.horizontalAccuracy)m)")
                        }
                    }
                }
                throw LocationError.failed
            }

            // Task 2: Timeout
            group.addTask {
                try await Task.sleep(for: .seconds(self.locationTimeout))
                throw LocationError.timedOut
            }

            // Return whichever finishes first
            guard let location = try await group.next() else {
                throw LocationError.failed
            }
            // Cancel the remaining task (timeout or location listener)
            group.cancelAll()

            self.lastKnownLocation = location
            return location
        }
    }

    // MARK: - Reverse geocoding

    /// Reverse geocode to a nice display string (e.g., "Adyar, Chennai, Tamil Nadu").
    func placename(for location: CLLocation) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    if let clErr = error as? CLError, clErr.code == .denied {
                        continuation.resume(throwing: LocationError.permissionDenied)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let p = placemarks?.first else {
                    continuation.resume(throwing: LocationError.reverseGeocodeFailed)
                    return
                }

                // Build a nice place name: "Sublocality, City, State"
                let subLocality = p.subLocality
                let city = p.locality
                let admin = p.administrativeArea
                let country = p.country

                var components: [String] = []
                if let sub = subLocality, !sub.isEmpty { components.append(sub) }
                if let c = city, !c.isEmpty, c != subLocality { components.append(c) }
                if let a = admin, !a.isEmpty, a != city { components.append(a) }
                if components.isEmpty, let c = country, !c.isEmpty { components.append(c) }

                if !components.isEmpty {
                    continuation.resume(returning: components.joined(separator: ", "))
                } else if let name = p.name, !name.isEmpty {
                    continuation.resume(returning: name)
                } else {
                    let coordStr = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
                    continuation.resume(returning: coordStr)
                }
            }
        }
    }

    // MARK: - Utility

    /// Checks if a coordinate is roughly within India's bounding box.
    static func isInIndia(_ coord: CLLocationCoordinate2D) -> Bool {
        return coord.latitude >= 6.0 && coord.latitude <= 38.0
            && coord.longitude >= 67.0 && coord.longitude <= 98.0
    }
}

// MARK: - Error descriptions

extension AppLocationManager.LocationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is denied. Enable it in Settings > Privacy > Location Services for Rentiwise."
        case .servicesDisabled:
            return "Location Services are turned off on this device. Please enable Location Services in Settings."
        case .failed:
            return "Couldn't determine your current location. Please try again."
        case .timedOut:
            return "Location request timed out. Make sure you have a clear view of the sky or try again."
        case .reverseGeocodeFailed:
            return "Couldn't find a place name for your location. Please try again."
        }
    }
}
