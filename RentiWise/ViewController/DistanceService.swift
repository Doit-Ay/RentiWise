import Foundation
import CoreLocation
import MapKit
import Supabase

/// Computes and caches road distance (automobile) between the viewer's default address
/// and another user's default address.
/// Source of truth for both ends is `public.addresses.latitude/longitude`.
final class DistanceService {

    static let shared = DistanceService()

    // MARK: - Config

    /// Maximum radius (in meters) within which items are visible to the user.
    /// All views (Home, Categories, Search) must use this single source of truth.
    static let nearbyRadiusMeters: Double = 30_000 // 30 km

    private let ttl: TimeInterval = 30 * 24 * 60 * 60
    private let transportType: MKDirectionsTransportType = .automobile
    private let viewerAddressCacheTTL: TimeInterval = 5 * 60
    private let defaultViewerAddress = "Current Location"

    // Fallback coordinate: used only when ALL lookups fail (no GPS, no DB, no saved address).
    // Using (0, 0) — Null Island — so the computed distance to any real item will be
    // enormous and correctly excluded by the nearby radius filter.
    private let fallbackCoordinate = CLLocation(latitude: 0.0, longitude: 0.0)

    /// Sentinel value returned by `rankingDistanceMeters` when the owner's or viewer's
    /// coordinates cannot be resolved. Guarantees exclusion from any radius filter.
    private static let unresolvedDistance: Double = Double.greatestFiniteMagnitude

    // MARK: - In-memory caches
    private var geocodeCache = NSCache<NSString, CLLocation>()
    private var directionsCache = NSCache<NSString, NSNumber>() // meters
    private var ownerCoordCache = NSCache<NSString, CLLocation>() // owner_id → CLLocation

    private let client: SupabaseClient
    private let geocoder = CLGeocoder()

    // MARK: - UserDefaults keys for the viewer's resolved default address
    private let viewerAddressUserIdKeyBase = "RW_ViewerAddressUserId"
    private let viewerAddressLatKeyBase = "RW_ViewerAddressLatitude"
    private let viewerAddressLonKeyBase = "RW_ViewerAddressLongitude"
    private let viewerAddressHashKeyBase = "RW_ViewerAddressHash"
    private let viewerAddressFetchedAtKeyBase = "RW_ViewerAddressFetchedAt"
    /// When true, the viewer coordinate was explicitly set by the user (e.g. picking a saved address).
    /// In this case, resolveViewerAddress() should NOT overwrite it with the DB default.
    private let viewerAddressExplicitKeyBase = "RW_ViewerAddressExplicit"

    private init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        geocodeCache.countLimit = 256
        geocodeCache.totalCostLimit = 4 * 1024 * 1024
        directionsCache.countLimit = 512
        directionsCache.totalCostLimit = 2 * 1024 * 1024
        ownerCoordCache.countLimit = 128
    }

    private func normalizedViewerScope(for userId: String? = nil) -> String {
        let rawUserId = userId ?? SupabaseManager.shared.currentUserIdSync() ?? "anonymous"
        let normalized = rawUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "anonymous" : normalized
    }

    private func viewerAddressKey(_ baseKey: String, userId: String? = nil) -> String {
        "\(baseKey).\(normalizedViewerScope(for: userId))"
    }

    // MARK: - Public API

    /// Returns the viewer's resolved coordinate from the local cache, or nil if it has not
    /// been resolved from `addresses` yet.
    func cachedViewerCoordinate() -> CLLocation? {
        cachedViewerAddressLocation(for: normalizedViewerScope())
    }

    func clearViewerAddressCache() {
        clearViewerAddressCache(for: normalizedViewerScope())
    }

    private func clearViewerAddressCache(for userId: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressUserIdKeyBase, userId: userId))
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressLatKeyBase, userId: userId))
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressLonKeyBase, userId: userId))
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressHashKeyBase, userId: userId))
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressFetchedAtKeyBase, userId: userId))
        defaults.removeObject(forKey: viewerAddressKey(viewerAddressExplicitKeyBase, userId: userId))
    }

    /// Clears ALL distance caches — viewer address, in-memory directions/geocode, and owner cache.
    /// Call this whenever the user's location changes so every distance is recomputed.
    func clearAllDistanceCaches() {
        clearViewerAddressCache()
        directionsCache.removeAllObjects()
        geocodeCache.removeAllObjects()
        ownerCoordCache.removeAllObjects()
        print("[DistanceService] All caches cleared")
    }

    /// Directly set the viewer's coordinate, bypassing DB/GPS lookups.
    /// Used when the user picks a saved address with known lat/lon from the location picker.
    func setViewerCoordinate(latitude: Double, longitude: Double) {
        let userId = normalizedViewerScope()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let resolved = ResolvedAddressCoordinate(
            userId: userId,
            location: location,
            hash: viewerAddressHash(for: location)
        )
        // Clear stale distances before setting new location
        directionsCache.removeAllObjects()
        ownerCoordCache.removeAllObjects()
        saveViewerAddress(resolved)
        // Mark as explicitly set so resolveViewerAddress doesn't overwrite with DB default
        UserDefaults.standard.set(true, forKey: viewerAddressKey(viewerAddressExplicitKeyBase, userId: userId))
        print("[DistanceService] Viewer coordinate explicitly set: \(latitude), \(longitude)")
    }

    /// Returns a stable numeric distance for ranking lists.
    /// Returns `0` for the user's own items.
    /// Returns `Double.greatestFiniteMagnitude` when viewer or owner coordinates are unresolvable,
    /// so the item is correctly excluded from radius-based filters.
    func rankingDistanceMeters(for item: Item) async -> Double {
        let viewerAddress = await resolveViewerAddress()

        // Own item — always 0 so it passes any radius filter
        if viewerAddress.userId.caseInsensitiveCompare(item.owner_id) == .orderedSame {
            return 0
        }

        // If the viewer's location couldn't be resolved (fallback 0,0), we can't compute
        // a meaningful distance. Return sentinel so item is excluded from radius filters
        // but can still be shown with a "distance unavailable" label.
        guard isValidCoordinate(viewerAddress.location) else {
            return Self.unresolvedDistance
        }

        if let cached = await fetchCachedDistanceMeters(
            viewerUserId: viewerAddress.userId,
            ownerUserId: item.owner_id,
            itemId: nil,
            viewerAddressHash: viewerAddress.hash,
            transportType: "automobile",
            ttl: ttl
        ) {
            return cached
        }

        let ownerCoord = await fetchOwnerCoordinate(ownerId: item.owner_id)

        // If the owner's location couldn't be resolved, return sentinel
        guard isValidCoordinate(ownerCoord) else {
            return Self.unresolvedDistance
        }

        return viewerAddress.location.distance(from: ownerCoord)
    }

    // MARK: - Radius filtering (used by Home, Categories, Search)

    /// Filters items within the configured `nearbyRadiusMeters` and sorts by distance ascending.
    /// Own items (distance == 0) always pass. Items with unresolvable coordinates are excluded.
    func filterItemsWithinRadius(_ items: [Item]) async -> [Item] {
        return await filterAndSortByDistance(items, radiusMeters: Self.nearbyRadiusMeters)
    }

    /// Filters items within the given radius and sorts by distance ascending.
    /// Own items always pass. Items with unresolvable coordinates are excluded.
    func filterAndSortByDistance(_ items: [Item], radiusMeters: Double) async -> [Item] {
        let me = await SupabaseManager.shared.currentUserId()

        let itemsWithDistance: [(Item, Double)] = await withTaskGroup(of: (Item, Double).self) { group in
            for item in items {
                group.addTask {
                    let meters = await self.rankingDistanceMeters(for: item)
                    return (item, meters)
                }
            }
            var results: [(Item, Double)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        return itemsWithDistance
            .filter { pair in
                let (item, distance) = pair
                // Own items always pass
                if let me, me.caseInsensitiveCompare(item.owner_id) == .orderedSame {
                    return true
                }
                // Unresolved coordinates — exclude
                if distance >= Self.unresolvedDistance {
                    return false
                }
                // Within radius
                return distance <= radiusMeters
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    /// Computes the viewer's distance to another user, typically used on lender/borrower cards.
    func distanceText(toUserId userId: String) async -> String {
        let viewerUserId = await SupabaseManager.shared.currentUserId()

        if let viewerUserId, viewerUserId.caseInsensitiveCompare(userId) == .orderedSame {
            return "Your item"
        }

        return await distanceText(
            toOwnerUserId: userId,
            cacheItemId: nil,
            progressiveUpdate: nil
        )
    }

    /// Returns a formatted distance string like "2.3 km" or "850 m".
    /// Distances are always computed from the current viewer's default address row to the item's
    /// owner's default address row.
    func distanceText(for item: Item, progressiveUpdate: ((String) -> Void)? = nil) async -> String {
        let viewerUserId = await SupabaseManager.shared.currentUserId()

        if let viewerUserId, viewerUserId.caseInsensitiveCompare(item.owner_id) == .orderedSame {
            return "Your item"
        }

        return await distanceText(
            toOwnerUserId: item.owner_id,
            cacheItemId: nil,
            progressiveUpdate: progressiveUpdate
        )
    }

    // MARK: - Address resolution

    private struct ResolvedAddressCoordinate {
        let userId: String
        let location: CLLocation
        let hash: String
    }

    private struct AddressCoordinateRow: Decodable {
        let user_id: String
        let latitude: Double?
        let longitude: Double?
        let is_default: Bool?
        let created_at: String?
    }

    private func distanceText(
        toOwnerUserId ownerUserId: String,
        cacheItemId: String?,
        progressiveUpdate: ((String) -> Void)?
    ) async -> String {
        let viewerAddress = await resolveViewerAddress()
        let ownerAddress = await fetchOwnerCoordinate(ownerId: ownerUserId)

        if let cached = await fetchCachedDistanceMeters(
            viewerUserId: viewerAddress.userId,
            ownerUserId: ownerUserId,
            itemId: cacheItemId,
            viewerAddressHash: viewerAddress.hash,
            transportType: "automobile",
            ttl: ttl
        ) {
            return formatDistance(meters: cached)
        }

        let straight = viewerAddress.location.distance(from: ownerAddress)
        let preliminaryText = formatDistance(meters: straight)
        let memKey = directionsCacheKey(
            viewer: viewerAddress.location,
            owner: ownerAddress,
            transport: transportType
        )

        if let cached = directionsCache.object(forKey: memKey as NSString)?.doubleValue {
            Task { [weak self] in
                await self?.upsertDistanceMeters(
                    cached,
                    viewerUserId: viewerAddress.userId,
                    ownerUserId: ownerUserId,
                    itemId: cacheItemId,
                    viewerAddressHash: viewerAddress.hash,
                    transportType: "automobile"
                )
            }
            return formatDistance(meters: cached)
        }

        if let progressiveUpdate {
            Task { [weak self] in
                guard let self else { return }
                if let meters = await routeDistanceMeters(
                    from: viewerAddress.location,
                    to: ownerAddress,
                    transport: transportType
                ) {
                    directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
                    await upsertDistanceMeters(
                        meters,
                        viewerUserId: viewerAddress.userId,
                        ownerUserId: ownerUserId,
                        itemId: cacheItemId,
                        viewerAddressHash: viewerAddress.hash,
                        transportType: "automobile"
                    )
                    let roadText = formatDistance(meters: meters)
                    await MainActor.run { progressiveUpdate(roadText) }
                }
            }
            return preliminaryText
        }

        if let meters = await routeDistanceMeters(
            from: viewerAddress.location,
            to: ownerAddress,
            transport: transportType
        ) {
            directionsCache.setObject(NSNumber(value: meters), forKey: memKey as NSString)
            await upsertDistanceMeters(
                meters,
                viewerUserId: viewerAddress.userId,
                ownerUserId: ownerUserId,
                itemId: cacheItemId,
                viewerAddressHash: viewerAddress.hash,
                transportType: "automobile"
            )
            return formatDistance(meters: meters)
        }

        await upsertDistanceMeters(
            straight,
            viewerUserId: viewerAddress.userId,
            ownerUserId: ownerUserId,
            itemId: cacheItemId,
            viewerAddressHash: viewerAddress.hash,
            transportType: "automobile",
            straightMeters: straight
        )
        return preliminaryText
    }

    private func resolveViewerAddress() async -> ResolvedAddressCoordinate {
        // Use a placeholder user id when not logged in so we can still compute distance
        let userId = normalizedViewerScope(for: await SupabaseManager.shared.currentUserId())

        if let cached = cachedViewerAddress(for: userId) {
            return cached
        }

        // Check if user explicitly set coordinates via location picker.
        let isExplicit = UserDefaults.standard.bool(forKey: viewerAddressKey(viewerAddressExplicitKeyBase, userId: userId))

        // 1) HIGHEST PRIORITY: Try device GPS (real-time location)
        if !isExplicit {
            if let coordinates = await AppLocationManager.shared.currentCoordinates() {
                let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
                let resolved = ResolvedAddressCoordinate(
                    userId: userId,
                    location: location,
                    hash: viewerAddressHash(for: location)
                )
                print("[DistanceService] Viewer resolved from GPS: \(coordinates.latitude), \(coordinates.longitude)")
                saveViewerAddress(resolved)
                if userId != "anonymous" {
                    await autoSaveAddressIfNeeded(userId: userId, location: location)
                }
                return resolved
            }
        }

        // 2) Try DB addresses table (user's saved default address)
        if !isExplicit {
            if userId != "anonymous", let resolved = await fetchViewerAddressCoordinate(userId: userId) {
                print("[DistanceService] Viewer resolved from DB: \(resolved.location.coordinate.latitude), \(resolved.location.coordinate.longitude)")
                saveViewerAddress(resolved)
                return resolved
            }
        }

        // 3) Try SavedAddressesStore (local UserDefaults — user's explicit selection)
        let savedAddress = SavedAddressesStore.shared.getDefaultSelectedAddress()?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedAddress, !savedAddress.isEmpty, savedAddress != "Current Location" {
            if let location = await geocodeAddressString(savedAddress) {
                let resolved = ResolvedAddressCoordinate(
                    userId: userId,
                    location: location,
                    hash: normalizeAddressKey(savedAddress)
                )
                print("[DistanceService] Viewer resolved from SavedAddressesStore geocode('\(savedAddress)'): \(location.coordinate.latitude), \(location.coordinate.longitude)")
                saveViewerAddress(resolved)
                return resolved
            }
        }

        // 4) If explicit was set but the cache expired, fall back to DB now
        if isExplicit, userId != "anonymous", let resolved = await fetchViewerAddressCoordinate(userId: userId) {
            print("[DistanceService] Viewer resolved from DB (explicit cache expired): \(resolved.location.coordinate.latitude), \(resolved.location.coordinate.longitude)")
            saveViewerAddress(resolved)
            return resolved
        }

        // 5) Ultimate fallback: try GPS one more time with authorization prompt
        do {
            let loc = try await AppLocationManager.shared.currentLocation()
            let resolved = ResolvedAddressCoordinate(
                userId: userId,
                location: loc,
                hash: viewerAddressHash(for: loc)
            )
            print("[DistanceService] Viewer resolved from GPS (with auth): \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            saveViewerAddress(resolved)
            return resolved
        } catch {
            // GPS truly unavailable
        }

        // 6) No location at all — return a zero-coordinate marker
        print("[DistanceService] ⚠️ Viewer: ALL lookups failed, no location available")
        let resolved = ResolvedAddressCoordinate(
            userId: userId,
            location: fallbackCoordinate,
            hash: viewerAddressHash(for: fallbackCoordinate)
        )
        saveViewerAddress(resolved)
        return resolved
    }

    private func fetchViewerAddressCoordinate(userId: String) async -> ResolvedAddressCoordinate? {
        do {
            let rows: [AddressCoordinateRow] = try await client
                .from("addresses")
                .select("user_id,latitude,longitude,is_default,created_at")
                .eq("user_id", value: userId)
                .order("is_default", ascending: false)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value

            for row in rows {
                guard let location = validatedLocation(latitude: row.latitude, longitude: row.longitude) else {
                    continue
                }

                return ResolvedAddressCoordinate(
                    userId: row.user_id,
                    location: location,
                    hash: viewerAddressHash(for: location)
                )
            }
        } catch {
            print("[DistanceService] fetchAddressCoordinate error: \(error)")
        }

        return nil
    }

    private struct PublicDefaultAddressRow: Decodable {
        let user_id: String
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
    }

    private func fetchOwnerCoordinate(ownerId: String) async -> CLLocation {
        // Check in-memory cache first
        let cacheKey = ownerId.lowercased() as NSString
        if let cached = ownerCoordCache.object(forKey: cacheKey) {
            return cached
        }

        // 1) Try RPC function (SECURITY DEFINER — bypasses RLS for cross-user lookups)
        do {
            let rows: [PublicDefaultAddressRow] = try await client
                .rpc("get_owner_coordinates", params: ["owner_user_id": ownerId])
                .execute()
                .value

            if let row = rows.first {
                print("[DistanceService] Owner \(ownerId) from RPC: lat=\(row.latitude ?? -999), lon=\(row.longitude ?? -999), city=\(row.city ?? "nil")")
                if let location = validatedLocation(latitude: row.latitude, longitude: row.longitude) {
                    ownerCoordCache.setObject(location, forKey: cacheKey)
                    return location
                }

                // Lat/lon are NULL but city is available — geocode and backfill
                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty, let geocoded = await geocodeAddressString(parts) {
                    print("[DistanceService] Owner \(ownerId) geocoded '\(parts)' -> \(geocoded.coordinate.latitude), \(geocoded.coordinate.longitude)")
                    ownerCoordCache.setObject(geocoded, forKey: cacheKey)
                    // Backfill the coordinates into the DB so future lookups are instant
                    await backfillOwnerCoordinates(ownerId: ownerId, location: geocoded)
                    return geocoded
                }
            } else {
                print("[DistanceService] Owner \(ownerId): NO rows from RPC get_owner_coordinates")
            }
        } catch {
            print("[DistanceService] fetchOwnerCoordinate RPC error: \(error)")
        }

        // 2) Try user_default_address view (fallback)
        do {
            let rows: [PublicDefaultAddressRow] = try await client
                .from("user_default_address")
                .select("user_id,latitude,longitude,city,state,country")
                .eq("user_id", value: ownerId)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                print("[DistanceService] Owner \(ownerId) from view: lat=\(row.latitude ?? -999), lon=\(row.longitude ?? -999), city=\(row.city ?? "nil")")
                if let location = validatedLocation(latitude: row.latitude, longitude: row.longitude) {
                    ownerCoordCache.setObject(location, forKey: cacheKey)
                    return location
                }

                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !parts.isEmpty, let geocoded = await geocodeAddressString(parts) {
                    ownerCoordCache.setObject(geocoded, forKey: cacheKey)
                    await backfillOwnerCoordinates(ownerId: ownerId, location: geocoded)
                    return geocoded
                }
            }
        } catch {
            print("[DistanceService] fetchOwnerCoordinate view error: \(error)")
        }

        // 3) Try addresses table directly (works with new RLS policy)
        if let ownAddress = await fetchViewerAddressCoordinate(userId: ownerId) {
            print("[DistanceService] Owner \(ownerId) from addresses table: \(ownAddress.location.coordinate.latitude), \(ownAddress.location.coordinate.longitude)")
            ownerCoordCache.setObject(ownAddress.location, forKey: cacheKey)
            return ownAddress.location
        }

        // 4) Ultimate fallback: Chennai coordinate
        print("[DistanceService] ⚠️ Owner \(ownerId): ALL lookups failed, using Chennai fallback")
        return fallbackCoordinate
    }

    /// Writes resolved lat/lon back to the addresses table for an owner whose row had NULL coordinates.
    /// This is a one-time backfill so future lookups are instant.
    private func backfillOwnerCoordinates(ownerId: String, location: CLLocation) async {
        struct CoordPatch: Encodable {
            let latitude: Double
            let longitude: Double
        }
        do {
            try await client
                .from("addresses")
                .update(CoordPatch(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ))
                .eq("user_id", value: ownerId)
                .is("latitude", value: nil)
                .execute()
            print("[DistanceService] Backfilled coordinates for owner \(ownerId)")
        } catch {
            // Non-critical — the update may fail if RLS blocks it, but the SECURITY DEFINER
            // RPC already has the coords cached for this session.
            print("[DistanceService] backfillOwnerCoordinates error (non-critical): \(error)")
        }
    }

    private func validatedLocation(latitude: Double?, longitude: Double?) -> CLLocation? {
        guard let latitude, let longitude, latitude != 0, longitude != 0 else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }

        return CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Returns true if the location has valid, non-zero coordinates (i.e. not the fallback).
    private func isValidCoordinate(_ location: CLLocation) -> Bool {
        let coord = location.coordinate
        return coord.latitude != 0.0 || coord.longitude != 0.0
    }

    private func cachedViewerAddress(for userId: String) -> ResolvedAddressCoordinate? {
        let defaults = UserDefaults.standard
        let viewerUserIdKey = viewerAddressKey(viewerAddressUserIdKeyBase, userId: userId)
        let fetchedAtKey = viewerAddressKey(viewerAddressFetchedAtKeyBase, userId: userId)
        let hashKey = viewerAddressKey(viewerAddressHashKeyBase, userId: userId)

        guard defaults.string(forKey: viewerUserIdKey)?.caseInsensitiveCompare(userId) == .orderedSame else {
            return nil
        }

        let fetchedAt = defaults.double(forKey: fetchedAtKey)
        guard fetchedAt > 0 else { return nil }

        let age = Date().timeIntervalSince1970 - fetchedAt
        guard age <= viewerAddressCacheTTL else { return nil }

        guard let location = cachedViewerAddressLocation(for: userId),
              let hash = defaults.string(forKey: hashKey) else {
            return nil
        }

        return ResolvedAddressCoordinate(userId: userId, location: location, hash: hash)
    }

    private func cachedViewerAddressLocation(for userId: String) -> CLLocation? {
        let defaults = UserDefaults.standard
        let latitude = defaults.double(forKey: viewerAddressKey(viewerAddressLatKeyBase, userId: userId))
        let longitude = defaults.double(forKey: viewerAddressKey(viewerAddressLonKeyBase, userId: userId))
        return validatedLocation(latitude: latitude, longitude: longitude)
    }

    private func saveViewerAddress(_ address: ResolvedAddressCoordinate) {
        let defaults = UserDefaults.standard
        let userId = normalizedViewerScope(for: address.userId)
        defaults.set(userId, forKey: viewerAddressKey(viewerAddressUserIdKeyBase, userId: userId))
        defaults.set(address.location.coordinate.latitude, forKey: viewerAddressKey(viewerAddressLatKeyBase, userId: userId))
        defaults.set(address.location.coordinate.longitude, forKey: viewerAddressKey(viewerAddressLonKeyBase, userId: userId))
        defaults.set(address.hash, forKey: viewerAddressKey(viewerAddressHashKeyBase, userId: userId))
        defaults.set(Date().timeIntervalSince1970, forKey: viewerAddressKey(viewerAddressFetchedAtKeyBase, userId: userId))
    }

    private func autoSaveAddressIfNeeded(userId: String, location: CLLocation) async {
        struct AddressCheck: Decodable { let id: String }
        struct AddressInsert: Encodable {
            let user_id: String
            let label: String
            let address_line1: String
            let city: String
            let state: String
            let postal_code: String
            let country: String
            let latitude: Double
            let longitude: Double
            let is_default: Bool
        }

        do {
            let existing: [AddressCheck] = try await client
                .from("addresses")
                .select("id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            guard existing.isEmpty else { return }

            // Reverse geocode to get city/state for the DB row
            var city = "Unknown"
            var state = ""
            var country = ""
            var postalCode = ""
            var addressLine1 = "Auto-detected location"

            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                if let p = placemarks.first {
                    city = p.locality ?? p.subLocality ?? city
                    state = p.administrativeArea ?? state
                    country = p.country ?? country
                    postalCode = p.postalCode ?? postalCode
                    addressLine1 = [p.subThoroughfare, p.thoroughfare, p.subLocality]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        addressLine1 = "\(city) area"
                    }
                }
            } catch {
                // Use defaults above
            }

            let payload = AddressInsert(
                user_id: userId,
                label: "Home",
                address_line1: addressLine1,
                city: city,
                state: state,
                postal_code: postalCode,
                country: country,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                is_default: true
            )
            _ = try await client.from("addresses").insert(payload).execute()
        } catch {
            print("[DistanceService] autoSaveAddressIfNeeded error: \(error)")
        }
    }

    private func viewerAddressHash(for location: CLLocation) -> String {
        let latitude = round(location.coordinate.latitude * 100000) / 100000
        let longitude = round(location.coordinate.longitude * 100000) / 100000
        return "\(latitude),\(longitude)"
    }

    private func geocodeAddressString(_ address: String) async -> CLLocation? {
        let key = normalizeAddressKey(address) as NSString

        if let cached = geocodeCache.object(forKey: key) {
            return cached
        }

        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let location = placemarks.first?.location {
                geocodeCache.setObject(location, forKey: key)
                return location
            }
        } catch {
            // ignore
        }

        return nil
    }

    private func normalizeAddressKey(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        let viewerLatitude = round(viewer.coordinate.latitude * 10000) / 10000
        let viewerLongitude = round(viewer.coordinate.longitude * 10000) / 10000
        let ownerLatitude = round(owner.coordinate.latitude * 10000) / 10000
        let ownerLongitude = round(owner.coordinate.longitude * 10000) / 10000
        return "dir:\(viewerLatitude),\(viewerLongitude)|\(ownerLatitude),\(ownerLongitude)|\(transport.rawValue)"
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

            if let date = ISO8601DateFormatter().date(from: row.computed_at),
               Date().timeIntervalSince(date) <= ttl {
                return Double(row.road_distance_m)
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
}
