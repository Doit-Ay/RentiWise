import Foundation
import CoreLocation
import MapKit
import Supabase

/// Computes and caches road distance (automobile) between the viewer's selected address
/// and an item's owner's default address.
/// Caches results per viewer/owner/address/transport in `public.user_item_distances` with a TTL.
/// Also caches geocoding results in-memory to avoid repeated CLGeocoder work.
final class DistanceService {

    static let shared = DistanceService()

    // MARK: - Config
    private let ttl: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let transportType: MKDirectionsTransportType = .automobile

    // MARK: - In-memory caches
    private var geocodeCache = NSCache<NSString, CLLocation>()
    private var directionsCache = NSCache<NSString, NSNumber>() // meters

    private let geocoder = CLGeocoder()
    private let client: SupabaseClient

    private init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        geocodeCache.countLimit = 128
        directionsCache.countLimit = 256
    }

    // MARK: - Public API

    /// Returns a formatted distance string like "2.3 km" or "850 m".
    /// Owner-level cache (item_id = null).
    func distanceText(for item: Item) async -> String? {
        guard let viewerAddressString = SavedAddressesStore.shared.getDefaultSelectedAddress(),
              !viewerAddressString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        guard let viewerUserId = await SupabaseManager.shared.currentUserId() else {
            // If not logged in, we can still compute without saving to DB.
            return await computeAndFormatWithoutDB(viewerAddressString: viewerAddressString, ownerId: item.owner_id)
        }

        // 1) Resolve coords
        guard let ownerCoord = await fetchOwnerCoordinate(ownerId: item.owner_id) else {
            return nil
        }
        guard let viewerCoord = await geocodeAddressString(viewerAddressString) else {
            return nil
        }

        // 2) Build a stable key/hash for viewer address
        let viewerAddressHash = normalizeAddressKey(viewerAddressString)

        // 3) Try DB cache first
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

        // 4) Try in-memory directions cache
        let memKey = directionsCacheKey(viewer: viewerCoord, owner: ownerCoord, transport: transportType)
        if let meters = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
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
            return formatDistance(meters: meters)
        }

        // 5) Compute road distance
        if let meters = await routeDistanceMeters(from: viewerCoord, to: ownerCoord, transport: transportType) {
            directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
            await upsertDistanceMeters(
                meters,
                viewerUserId: viewerUserId,
                ownerUserId: item.owner_id,
                itemId: nil,
                viewerAddressHash: viewerAddressHash,
                transportType: "automobile"
            )
            return formatDistance(meters: meters)
        }

        // 6) Fallback: straight-line distance
        let straight = viewerCoord.distance(from: ownerCoord)
        await upsertDistanceMeters(
            straight,
            viewerUserId: viewerUserId,
            ownerUserId: item.owner_id,
            itemId: nil,
            viewerAddressHash: viewerAddressHash,
            transportType: "automobile",
            straightMeters: straight
        )
        return formatDistance(meters: straight)
    }

    // MARK: - Owner coordinate from public view

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
                let parts = [row.city, row.state, row.country].compactMap { $0 }.joined(separator: ", ")
                if !parts.isEmpty {
                    return await geocodeAddressString(parts)
                }
            }
        } catch {
            // ignore
        }
        return nil
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
                // Alternatively:
                // query = query.filter("item_id", operator: "is", value: "null")
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
                .insert(payload)
                .execute()
        } catch {
            // ignore
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
        guard let ownerCoord = await fetchOwnerCoordinate(ownerId: ownerId),
              let viewerCoord = await geocodeAddressString(viewerAddressString) else {
            return nil
        }
        let memKey = directionsCacheKey(viewer: viewerCoord, owner: ownerCoord, transport: transportType)
        if let meters = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
            return formatDistance(meters: meters)
        }
        if let meters = await routeDistanceMeters(from: viewerCoord, to: ownerCoord, transport: transportType) {
            directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
            return formatDistance(meters: meters)
        }
        return formatDistance(meters: viewerCoord.distance(from: ownerCoord))
    }
}
