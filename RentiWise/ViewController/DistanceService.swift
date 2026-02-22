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
    
    // MARK: - UserDefaults keys for persistent coordinate caching
    private let userCoordLatKey = "RW_UserAddressLatitude"
    private let userCoordLonKey = "RW_UserAddressLongitude"
    private let userCoordAddressKey = "RW_UserAddressCached"

    private init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        // Count-based limit to cap the number of entries
        geocodeCache.countLimit = 256
        directionsCache.countLimit = 512
        // Cost-based limit to cap total memory usage on low-end devices
        geocodeCache.totalCostLimit = 4 * 1024 * 1024    // 4 MB
        directionsCache.totalCostLimit = 2 * 1024 * 1024 // 2 MB
    }

    // MARK: - Public API

    /// Returns a formatted distance string like "2.3 km" or "850 m".
    /// Owner-level cache (item_id = null).
    /// - Parameter progressiveUpdate: Optional closure called on the **Main thread** when
    ///   a more accurate road distance becomes available after the initial straight-line estimate.
    func distanceText(for item: Item, progressiveUpdate: ((String) -> Void)? = nil) async -> String {
        // 0) Get viewer address
        let viewerAddressString = SavedAddressesStore.shared.getDefaultSelectedAddress()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let viewerAddress = (viewerAddressString?.isEmpty == false) ? viewerAddressString! : defaultViewerAddress
        let viewerAddressHash = normalizeAddressKey(viewerAddress)
        let viewerUserId = await SupabaseManager.shared.currentUserId()

        // 1) FAST PATH: DB cache (logged-in users)
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

        // 2) Resolve owner coordinate (with wide fallbacks — never nil after this)
        let ownerCoord = await fetchOwnerCoordinate(ownerId: item.owner_id) ?? fallbackOwnerCoordinate

        // 3) Resolve viewer coordinate — only persist THIS to the user coord cache
        var viewerCoord = await geocodeAddressString(viewerAddress)
        if viewerCoord == nil { viewerCoord = await geocodeAddressString(defaultViewerAddress) }
        let resolvedViewerCoord = viewerCoord ?? fallbackOwnerCoordinate
        // Persist the viewer's resolved coordinate so future launches skip geocoding
        saveUserCoordinates(resolvedViewerCoord, for: viewerAddress)

        // 4) INSTANT straight-line distance — guarantees we always return something
        let straight = resolvedViewerCoord.distance(from: ownerCoord)
        let prelimText = formatDistance(meters: straight)

        // 5) Check in-memory directions cache
        let memKey = directionsCacheKey(viewer: resolvedViewerCoord, owner: ownerCoord, transport: transportType)
        if let cached = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
            if let viewerUserId {
                Task { [weak self] in
                    await self?.upsertDistanceMeters(cached, viewerUserId: viewerUserId, ownerUserId: item.owner_id,
                        itemId: nil, viewerAddressHash: viewerAddressHash, transportType: "automobile")
                }
            }
            return formatDistance(meters: cached)
        }

        // 6) Fire road-distance calculation in background; update via callback if provided
        if let progressiveUpdate {
            Task { [weak self] in
                guard let self else { return }
                if let meters = await routeDistanceMeters(from: resolvedViewerCoord, to: ownerCoord, transport: transportType) {
                    directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
                    if let viewerUserId {
                        await upsertDistanceMeters(meters, viewerUserId: viewerUserId, ownerUserId: item.owner_id,
                            itemId: nil, viewerAddressHash: viewerAddressHash, transportType: "automobile")
                    }
                    let roadText = formatDistance(meters: meters)
                    await MainActor.run { progressiveUpdate(roadText) }
                }
            }
            // Return straight-line immediately — never blank
            return prelimText
        } else {
            // Synchronous path: compute road distance now
            if let meters = await routeDistanceMeters(from: resolvedViewerCoord, to: ownerCoord, transport: transportType) {
                directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
                if let viewerUserId {
                    await upsertDistanceMeters(meters, viewerUserId: viewerUserId, ownerUserId: item.owner_id,
                        itemId: nil, viewerAddressHash: viewerAddressHash, transportType: "automobile")
                }
                return formatDistance(meters: meters)
            }
            // Road distance failed — cache straight-line in DB and return it
            if let viewerUserId {
                await upsertDistanceMeters(straight, viewerUserId: viewerUserId, ownerUserId: item.owner_id,
                    itemId: nil, viewerAddressHash: viewerAddressHash, transportType: "automobile", straightMeters: straight)
            }
            return prelimText
        }
    }

    // MARK: - Owner coordinate from public view (with fallback)

    private struct OwnerDefaultAddressRow: Decodable {
        let user_id: String
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
    }

    private func fetchOwnerCoordinate(ownerId: String) async -> CLLocation? {
        // Try user_default_address view first (use limit+first, NOT .single() — avoids error when no row)
        do {
            let response = try await client
                .from("user_default_address")
                .select("user_id,latitude,longitude,city,state,country")
                .eq("user_id", value: ownerId)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([OwnerDefaultAddressRow].self, from: response.data)
            if let row = rows.first {
                if let lat = row.latitude, let lon = row.longitude,
                   lat != 0.0, lon != 0.0 {
                    return CLLocation(latitude: lat, longitude: lon)
                }
                // Fallback to geocoding city/state/country if lat/lon missing/zero
                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty, let geocoded = await geocodeAddressString(parts) {
                    return geocoded
                }
            }
        } catch {
            // table/view may not exist — fall through
        }

        // Second attempt: try profiles table for city/state
        do {
            struct ProfileCityRow: Decodable { let city: String?; let state: String? }
            let response = try await client
                .from("profiles")
                .select("city,state")
                .eq("id", value: ownerId)
                .limit(1)
                .execute()
            let rows = try JSONDecoder().decode([ProfileCityRow].self, from: response.data)
            if let row = rows.first {
                let parts = [row.city, row.state]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty, let geocoded = await geocodeAddressString(parts) {
                    return geocoded
                }
            }
        } catch { }

        // Third attempt: users table
        do {
            struct UsersCityRow: Decodable { let city: String?; let state: String? }
            let response = try await client
                .from("users")
                .select("city,state")
                .eq("id", value: ownerId)
                .limit(1)
                .execute()
            let rows = try JSONDecoder().decode([UsersCityRow].self, from: response.data)
            if let row = rows.first {
                let parts = [row.city, row.state]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty, let geocoded = await geocodeAddressString(parts) {
                    return geocoded
                }
            }
        } catch { }

        return nil
    }

    // MARK: - Viewer geocoding with persistent caching
    
    /// Get cached user coordinates from UserDefaults (FAST - skip geocoding entirely)
    private func getCachedUserCoordinates(for address: String) -> CLLocation? {
        let normalizedAddress = normalizeAddressKey(address)
        let savedAddress = UserDefaults.standard.string(forKey: userCoordAddressKey)
        
        // Check if cached address matches current address
        guard normalizeAddressKey(savedAddress ?? "") == normalizedAddress else {
            return nil
        }
        
        let lat = UserDefaults.standard.double(forKey: userCoordLatKey)
        let lon = UserDefaults.standard.double(forKey: userCoordLonKey)
        
        // Validate coordinates (not zero/default)
        guard lat != 0.0 && lon != 0.0 else {
            return nil
        }
        
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Save user coordinates to UserDefaults for future use
    private func saveUserCoordinates(_ location: CLLocation, for address: String) {
        UserDefaults.standard.set(location.coordinate.latitude, forKey: userCoordLatKey)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: userCoordLonKey)
        UserDefaults.standard.set(address, forKey: userCoordAddressKey)
    }

    private func geocodeAddressString(_ s: String) async -> CLLocation? {
        // 1) Check persistent cache first (FASTEST — only populated for the viewer's own address)
        if let cached = getCachedUserCoordinates(for: s) {
            // Also warm the in-memory cache for consistency
            let key = normalizeAddressKey(s) as NSString
            geocodeCache.setObject(cached, forKey: key)
            return cached
        }

        // 2) Check in-memory cache
        let key = normalizeAddressKey(s) as NSString
        if let cached = geocodeCache.object(forKey: key) {
            // Note: do NOT call saveUserCoordinates here — this may be an owner/city address
            return cached
        }

        // 3) Geocode (SLOW — only happens once per address)
        do {
            let placemarks = try await geocoder.geocodeAddressString(s)
            if let loc = placemarks.first?.location {
                // Save to in-memory cache only; persistent user coord cache is written
                // exclusively by distanceText after resolving the viewer's own address.
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

    /// Payload for inserting/updating a cached distance row.
    /// `computed_at` is intentionally omitted — the DB column has a server-side
    /// default of `now()`, so it is set automatically on every upsert.
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

}
