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
    
    /// Cached last known location for quick access
    private(set) var lastKnownLocation: CLLocation?
    
    /// Cached last known coordinate for quick access
    var lastKnownCoordinate: CLLocationCoordinate2D? {
        lastKnownLocation?.coordinate
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    enum LocationError: Error, LocalizedError {
        case permissionDenied
        case servicesDisabled
        case failed
        case reverseGeocodeFailed
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Location permission was denied"
            case .servicesDisabled:
                return "Location services are disabled"
            case .failed:
                return "Failed to get location"
            case .reverseGeocodeFailed:
                return "Failed to reverse geocode location"
            }
        }
    }

    // MARK: - Authorization
    
    /// Request When-In-Use authorization if needed.
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
    
    /// Check if we have location permission
    var hasLocationPermission: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    // MARK: - Current Location
    
    /// One-shot current location (ensures authorization first).
    func currentLocation() async throws -> CLLocation {
        try await ensureWhenInUseAuthorization()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }
    
    /// Get current location as coordinate (convenience method).
    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        let location = try await currentLocation()
        return location.coordinate
    }
    
    /// Try to get location, returns nil if fails (non-throwing convenience).
    func currentLocationOrNil() async -> CLLocation? {
        do {
            return try await currentLocation()
        } catch {
            return lastKnownLocation
        }
    }

    // MARK: - Reverse Geocoding
    
    /// Reverse geocode to a nice display string (e.g., "Chennai, Tamil Nadu").
    func placename(for location: CLLocation) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
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
    
    /// Get placename for current location.
    func currentPlacename() async -> String {
        do {
            let location = try await currentLocation()
            return try await placename(for: location)
        } catch {
            return SavedAddressesStore.shared.getDefaultSelectedAddress() ?? "Unknown Location"
        }
    }
}

// MARK: - CLLocationManagerDelegate

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
            // Cache the location
            lastKnownLocation = loc
            continuation.resume(returning: loc)
        } else {
            continuation.resume(throwing: LocationError.failed)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }
}
