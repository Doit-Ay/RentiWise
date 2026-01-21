//
//  DistanceService.swift
//  RentiWise
//
//  Created for real distance calculation using Apple MapKit.
//

import Foundation
import CoreLocation
import MapKit

/// Service for calculating real road-based distances between locations.
/// Uses Apple's MapKit (free, no API key required).
final class DistanceService {
    
    static let shared = DistanceService()
    
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    // MARK: - Error Types
    
    enum DistanceError: Error, LocalizedError {
        case geocodingFailed(String)
        case directionsNotAvailable
        case noRouteFound
        case invalidCoordinates
        
        var errorDescription: String? {
            switch self {
            case .geocodingFailed(let address):
                return "Could not find location for: \(address)"
            case .directionsNotAvailable:
                return "Directions service is not available"
            case .noRouteFound:
                return "No route found between locations"
            case .invalidCoordinates:
                return "Invalid coordinates provided"
            }
        }
    }
    
    // MARK: - Geocoding (Address → Coordinates)
    
    /// Convert an address string to coordinates.
    /// - Parameter address: The address string (e.g., "Home, Chennai" or "SRMIST, Kattankulathur")
    /// - Returns: CLLocationCoordinate2D of the address
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: DistanceError.geocodingFailed("\(address): \(error.localizedDescription)"))
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: DistanceError.geocodingFailed(address))
                    return
                }
                
                continuation.resume(returning: location.coordinate)
            }
        }
    }
    
    // MARK: - Distance Calculation (Road-Based)
    
    /// Calculate the driving distance between two coordinates.
    /// - Parameters:
    ///   - from: Source coordinates
    ///   - to: Destination coordinates
    /// - Returns: Distance in meters
    func calculateDrivingDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> CLLocationDistance {
        // Validate coordinates
        guard CLLocationCoordinate2DIsValid(source) && CLLocationCoordinate2DIsValid(destination) else {
            throw DistanceError.invalidCoordinates
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let error = error {
                    // Fallback to straight-line distance if directions fail
                    let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
                    let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
                    let straightLineDistance = sourceLocation.distance(from: destLocation)
                    // Add ~30% to approximate road distance
                    continuation.resume(returning: straightLineDistance * 1.3)
                    return
                }
                
                guard let route = response?.routes.first else {
                    // Fallback to straight-line distance
                    let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
                    let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
                    let straightLineDistance = sourceLocation.distance(from: destLocation)
                    continuation.resume(returning: straightLineDistance * 1.3)
                    return
                }
                
                continuation.resume(returning: route.distance)
            }
        }
    }
    
    /// Calculate distance from user's current/selected location to an item's location.
    /// - Parameters:
    ///   - itemLatitude: Item's latitude
    ///   - itemLongitude: Item's longitude
    /// - Returns: Formatted distance string (e.g., "4.2 km")
    func calculateDistanceToItem(itemLatitude: Double?, itemLongitude: Double?) async -> String {
        // If item has no coordinates, return placeholder
        guard let itemLat = itemLatitude, let itemLng = itemLongitude else {
            return "Distance N/A"
        }
        
        let itemCoordinate = CLLocationCoordinate2D(latitude: itemLat, longitude: itemLng)
        
        do {
            // Try to get user's location
            let userCoordinate = try await getUserCoordinate()
            let distanceMeters = try await calculateDrivingDistance(from: userCoordinate, to: itemCoordinate)
            return formatDistance(distanceMeters)
        } catch {
            print("Distance calculation failed: \(error.localizedDescription)")
            return "Distance N/A"
        }
    }
    
    // MARK: - User Location
    
    /// Get user's coordinate either from GPS or saved address.
    private func getUserCoordinate() async throws -> CLLocationCoordinate2D {
        // First, try to get from GPS
        do {
            let location = try await AppLocationManager.shared.currentLocation()
            return location.coordinate
        } catch {
            // Fallback: Try to geocode the user's saved address
            if let savedAddress = SavedAddressesStore.shared.getDefaultSelectedAddress() {
                return try await geocodeAddress(savedAddress)
            }
            throw DistanceError.geocodingFailed("No user location available")
        }
    }
    
    // MARK: - Formatting
    
    /// Format distance in meters to a human-readable string.
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string (e.g., "4.2 km" or "850 m")
    func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        }
    }
    
    /// Calculate straight-line distance (faster, less accurate).
    /// Use this for quick estimates or when MKDirections fails.
    func straightLineDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return sourceLocation.distance(from: destLocation)
    }
}
