import Foundation
import CoreLocation
import MapKit
import Supabase

/// Computes and caches road distance (automobile) between the viewer's selected address
/// and an item's owner's default address.
/// Caches results per viewer/owner/address/transport in `public.user_item_distances` with a TTL.
/// Also caches geocoding results in-memory to avoid repeated CLGeocoder work.
///
/// Robust fallbacks so a distance string is always produced:
/// - If viewer address is missing/un-geocodable, use a default campus address.
/// - If owner coords/view are missing/un-geocodable, fall back to a known campus coordinate.
/// - If routing fails, fall back to straight-line distance.
final class DistanceService {

    static let shared = DistanceService()

    // MARK: - Config
    private let ttl: TimeInterval = 30 * 24 * 60 * 60 // 30 days (distance rarely changes)
    private let transportType: MKDirectionsTransportType = .automobile

    // Full geocodable default viewer address (adjust to your preferred default).
    private let defaultViewerAddress = "SRM Institute of Science and Technology, Kattankulathur, Tamil Nadu, India"

    // Fallback coordinate near SRM Kattankulathur; ensures owner coords exist when not available.
    private let fallbackOwnerCoordinate = CLLocation(latitude: 12.8230, longitude: 80.0450)

    // MARK: - In-memory caches
    private var geocodeCache = NSCache<NSString, CLLocation>()
    private var directionsCache = NSCache<NSString, NSNumber>() // meters

    private let geocoder = CLGeocoder()
    private let client: SupabaseClient

    private init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        geocodeCache.countLimit = 256  // Increased from 128
        directionsCache.countLimit = 512  // Increased from 256
    }

    // MARK: - Public API

    /// Returns a formatted distance string like "2.3 km" or "850 m".
    /// Owner-level cache (item_id = null).
    func distanceText(for item: Item) async -> String {
        // 0) Get viewer address and user ID
        let viewerAddressString = SavedAddressesStore.shared.getDefaultSelectedAddress()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let viewerAddress = (viewerAddressString?.isEmpty == false) ? viewerAddressString! : defaultViewerAddress
        let viewerAddressHash = normalizeAddressKey(viewerAddress)
        let viewerUserId = await SupabaseManager.shared.currentUserId()

        // 1) FAST PATH: Check DB cache first (no geocoding needed!)
        if let viewerUserId {
            if let cached = await fetchCachedDistanceMeters(
                viewerUserId: viewerUserId,
                ownerUserId: item.owner_id,
                itemId: nil,
                viewerAddressHash: viewerAddressHash,
                transportType: "automobile",
                ttl: ttl
            ) {
                return formatDistance(meters: cached)
            }
        }

        // 2) SLOW PATH: Need to geocode and calculate
        // Resolve owner coords with fallback
        var ownerCoord = await fetchOwnerCoordinate(ownerId: item.owner_id)
        if ownerCoord == nil {
            ownerCoord = fallbackOwnerCoordinate
        }
        let resolvedOwnerCoord = ownerCoord!

        // Resolve viewer coords with fallback
        var viewerCoord = await geocodeAddressString(viewerAddress)
        if viewerCoord == nil {
            viewerCoord = await geocodeAddressString(defaultViewerAddress)
        }
        if viewerCoord == nil {
            viewerCoord = fallbackOwnerCoordinate
        }
        let resolvedViewerCoord = viewerCoord!

        // 3) Try in-memory directions cache
        let memKey = directionsCacheKey(viewer: resolvedViewerCoord, owner: resolvedOwnerCoord, transport: transportType)
        if let meters = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
            if let viewerUserId {
                Task { [weak self] in
                    await self?.upsertDistanceMeters(
                        meters,
                        viewerUserId: viewerUserId,
                        ownerUserId: item.owner_id,
                        itemId: nil,
                        viewerAddressHash: viewerAddressHash,
                        transportType: "automobile"
                    )
                }
            }
            return formatDistance(meters: meters)
        }

        // 4) Compute road distance
        if let meters = await routeDistanceMeters(from: resolvedViewerCoord, to: resolvedOwnerCoord, transport: transportType) {
            directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
            if let viewerUserId {
                await upsertDistanceMeters(
                    meters,
                    viewerUserId: viewerUserId,
                    ownerUserId: item.owner_id,
                    itemId: nil,
                    viewerAddressHash: viewerAddressHash,
                    transportType: "automobile"
                )
            }
            return formatDistance(meters: meters)
        }

        // 5) Fallback: straight-line distance
        let straight = resolvedViewerCoord.distance(from: resolvedOwnerCoord)
        if let viewerUserId {
            await upsertDistanceMeters(
                straight,
                viewerUserId: viewerUserId,
                ownerUserId: item.owner_id,
                itemId: nil,
                viewerAddressHash: viewerAddressHash,
                transportType: "automobile",
                straightMeters: straight
            )
        }
        return formatDistance(meters: straight)
    }

    // MARK: - Owner coordinate from public view (with fallback)

    private struct OwnerDefaultAddressRow: Decodable {
        let user_id: String
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
        let is_default: Bool?
        let created_at: String?
    }

    private func fetchOwnerCoordinate(ownerId: String) async -> CLLocation? {
        // Try view first
        do {
            let response = try await client
                .from("user_default_address")
                .select("user_id,latitude,longitude,city,state,country,is_default,created_at")
                .eq("user_id", value: ownerId)
                .single()
                .execute()

            if let data = response.data as? Data {
                let row = try JSONDecoder().decode(OwnerDefaultAddressRow.self, from: data)
                if let lat = row.latitude, let lon = row.longitude {
                    return CLLocation(latitude: lat, longitude: lon)
                }
                // Fallback to geocoding city/state/country if lat/lon missing
                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty {
                    return await geocodeAddressString(parts)
                }
            }
        } catch {
            // ignore and continue to fallback
        }
        // Final fallback so a distance is always shown
        return fallbackOwnerCoordinate
    }

    // MARK: - Viewer geocoding

    private func geocodeAddressString(_ s: String) async -> CLLocation? {
        let key = normalizeAddressKey(s) as NSString
        if let cached = geocodeCache.object(forKey: key) {
            return cached
        }
        do {
            let placemarks = try await geocoder.geocodeAddressString(s)
            if let loc = placemarks.first?.location {
                geocodeCache.setObject(loc, forKey: key)
                return loc
            }
        } catch {
            // ignore
        }
        return nil
    }

    private func normalizeAddressKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Directions

    private func routeDistanceMeters(from: CLLocation, to: CLLocation, transport: MKDirectionsTransportType) async -> Double? {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        req.transportType = transport

        let directions = MKDirections(request: req)
        do {
            let resp = try await directions.calculate()
            if let route = resp.routes.first {
                return route.distance
            }
        } catch {
            // ignore
        }
        return nil
    }

    private func directionsCacheKey(viewer: CLLocation, owner: CLLocation, transport: MKDirectionsTransportType) -> String {
        let v = "\(round(viewer.coordinate.latitude * 10000) / 10000),\(round(viewer.coordinate.longitude * 10000) / 10000)"
        let o = "\(round(owner.coordinate.latitude * 10000) / 10000),\(round(owner.coordinate.longitude * 10000) / 10000)"
        return "dir:\(v)|\(o)|\(transport.rawValue)"
    }

    // MARK: - DB cache read/write

    private struct DistanceRow: Decodable {
        let road_distance_m: Int
        let straight_distance_m: Int?
        let computed_at: String
    }

    private func fetchCachedDistanceMeters(
        viewerUserId: String,
        ownerUserId: String,
        itemId: String?,
        viewerAddressHash: String,
        transportType: String,
        ttl: TimeInterval
    ) async -> Double? {
        do {
            var query = client
                .from("user_item_distances")
                .select("road_distance_m,straight_distance_m,computed_at")
                .eq("viewer_user_id", value: viewerUserId)
                .eq("owner_user_id", value: ownerUserId)
                .eq("viewer_address_hash", value: viewerAddressHash)
                .eq("transport_type", value: transportType)

            if let itemId = itemId {
                query = query.eq("item_id", value: itemId)
            } else {
                // WHERE item_id IS NULL
                query = query.is("item_id", value: nil)
            }

            let response = try await query
                .order("computed_at", ascending: false)
                .limit(1)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let rows = try decoder.decode([DistanceRow].self, from: response.data)
            guard let row = rows.first else { return nil }

            if let date = ISO8601DateFormatter().date(from: row.computed_at) {
                if Date().timeIntervalSince(date) <= ttl {
                    return Double(row.road_distance_m)
                }
            }
        } catch {
            // ignore
        }
        return nil
    }

    private struct UpsertPayload: Encodable {
        let viewer_user_id: String
        let owner_user_id: String
        let item_id: String?
        let viewer_address_hash: String
        let transport_type: String
        let road_distance_m: Int
        let straight_distance_m: Int?
    }

    private func upsertDistanceMeters(
        _ meters: Double,
        viewerUserId: String,
        ownerUserId: String,
        itemId: String?,
        viewerAddressHash: String,
        transportType: String,
        straightMeters: Double? = nil
    ) async {
        let payload = UpsertPayload(
            viewer_user_id: viewerUserId,
            owner_user_id: ownerUserId,
            item_id: itemId,
            viewer_address_hash: viewerAddressHash,
            transport_type: transportType,
            road_distance_m: Int(meters.rounded()),
            straight_distance_m: straightMeters != nil ? Int(straightMeters!.rounded()) : nil
        )
        do {
            _ = try await client
                .from("user_item_distances")
                .upsert(payload)
                .execute()
        } catch {
            // ignore - cache update failures shouldn't break the app
        }
    }

    // MARK: - Formatting

    private func formatDistance(meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }

    // MARK: - Non-DB fallback (not logged in)

    private func computeAndFormatWithoutDB(viewerAddressString: String, ownerId: String) async -> String? {
        // Owner
        var ownerCoord = await fetchOwnerCoordinate(ownerId: ownerId)
        if ownerCoord == nil {
            ownerCoord = fallbackOwnerCoordinate
        }
        let resolvedOwnerCoord = ownerCoord!

        // Viewer
        var viewerCoord = await geocodeAddressString(viewerAddressString)
        if viewerCoord == nil {
            viewerCoord = await geocodeAddressString(defaultViewerAddress)
        }
        if viewerCoord == nil {
            viewerCoord = fallbackOwnerCoordinate
        }
        let resolvedViewerCoord = viewerCoord!

        let memKey = directionsCacheKey(viewer: resolvedViewerCoord, owner: resolvedOwnerCoord, transport: transportType)
        if let meters = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
            return formatDistance(meters: meters)
        }
        if let meters = await routeDistanceMeters(from: resolvedViewerCoord, to: resolvedOwnerCoord, transport: transportType) {
            directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
            return formatDistance(meters: meters)
        }
        return formatDistance(meters: resolvedViewerCoord.distance(from: resolvedOwnerCoord))
    }
}

