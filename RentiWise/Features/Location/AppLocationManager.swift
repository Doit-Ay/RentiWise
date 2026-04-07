//
//  AppLocationManager.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import Foundation
import CoreLocation

/// Thin wrapper over CLLocationManager to request When-In-Use permission,
/// fetch one-shot current location, and reverse geocode a readable place string.
final class AppLocationManager: NSObject {

    static let shared = AppLocationManager()

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private let geocoder = CLGeocoder()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    enum LocationError: Error {
        case permissionDenied
        case servicesDisabled
        case failed
        case reverseGeocodeFailed
    }

    /// Returns the device's current coordinates, or nil if unavailable or outside India.
    /// Does NOT prompt for permission — returns nil if not authorized.
    func currentCoordinates() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }
        do {
            let loc = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
                self.locationContinuation = continuation
                self.manager.requestLocation()
            }
            // Validate: reject simulator/non-India coordinates
            guard Self.isInIndia(loc.coordinate) else {
                debugLog("[AppLocationManager] GPS coordinate outside India (\(loc.coordinate.latitude), \(loc.coordinate.longitude)) — ignoring")
                return nil
            }
            return loc.coordinate
        } catch {
            return nil
        }
    }

    /// Checks if a coordinate is roughly within India's bounding box.
    /// India: latitude ~6.5 to ~37.1, longitude ~68.1 to ~97.4
    static func isInIndia(_ coord: CLLocationCoordinate2D) -> Bool {
        return coord.latitude >= 6.0 && coord.latitude <= 38.0
            && coord.longitude >= 67.0 && coord.longitude <= 98.0
    }
}

extension AppLocationManager.LocationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is denied. Enable it in Settings > Privacy > Location Services for Rentiwise."
        case .servicesDisabled:
            return "Location Services are turned off on this device. Please enable Location Services in Settings."
        case .failed:
            return "Couldn't determine your current location. Please try again."
        case .reverseGeocodeFailed:
            return "Couldn't find a place name for your location. Please try again."
        }
    }
}

extension AppLocationManager {
    // Request When-In-Use authorization if needed.
    func ensureWhenInUseAuthorization() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.servicesDisabled
        }

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.authContinuation = continuation
                self.manager.requestWhenInUseAuthorization()
            }
        case .restricted, .denied:
            throw LocationError.permissionDenied
        case .authorizedAlways, .authorizedWhenInUse:
            return
        @unknown default:
            return
        }
    }

    // One-shot current location (ensures authorization first).
    // Returns India-validated location; falls back to Chennai if GPS is outside India.
    func currentLocation() async throws -> CLLocation {
        try await ensureWhenInUseAuthorization()
        let loc = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
        // Validate: if GPS is outside India (e.g., simulator returns San Francisco), use Chennai
        if Self.isInIndia(loc.coordinate) {
            return loc
        } else {
            debugLog("[AppLocationManager] GPS outside India (\(loc.coordinate.latitude), \(loc.coordinate.longitude)) — using Chennai fallback")
            return CLLocation(latitude: 13.0827, longitude: 80.2707) // Chennai city center
        }
    }

    // Reverse geocode to a nice display string (e.g., "Chennai, Tamil Nadu").
    func placename(for location: CLLocation) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    // Map Core Location/Geocoder errors to a friendly message when possible
                    if let clErr = error as? CLError {
                        switch clErr.code {
                        case .denied:
                            continuation.resume(throwing: LocationError.permissionDenied)
                            return
                        default:
                            break
                        }
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let p = placemarks?.first else {
                    continuation.resume(throwing: LocationError.reverseGeocodeFailed)
                    return
                }
                let city = p.locality ?? p.subLocality
                let admin = p.administrativeArea ?? p.subAdministrativeArea
                let country = p.country
                let components = [city, admin, country].compactMap { $0 }.filter { !$0.isEmpty }
                if !components.isEmpty {
                    continuation.resume(returning: components.joined(separator: ", "))
                } else if let name = p.name, !name.isEmpty {
                    continuation.resume(returning: name)
                } else {
                    continuation.resume(returning: "Current Location")
                }
            }
        }
    }
}

extension AppLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authContinuation else { return }
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            authContinuation = nil
            continuation.resume()
        case .denied, .restricted:
            authContinuation = nil
            continuation.resume(throwing: LocationError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            authContinuation = nil
            continuation.resume()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        if let loc = locations.last {
            continuation.resume(returning: loc)
        } else {
            continuation.resume(throwing: LocationError.failed)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil

        // Map denied to a friendly, consistent error
        if let clErr = error as? CLError, clErr.code == .denied {
            continuation.resume(throwing: LocationError.permissionDenied)
            return
        }
        continuation.resume(throwing: error)
    }
}
