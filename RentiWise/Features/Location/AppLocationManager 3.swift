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
    func currentLocation() async throws -> CLLocation {
        try await ensureWhenInUseAuthorization()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }

    // Reverse geocode to a nice display string (e.g., "Chennai, Tamil Nadu").
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
        continuation.resume(throwing: error)
    }
}
