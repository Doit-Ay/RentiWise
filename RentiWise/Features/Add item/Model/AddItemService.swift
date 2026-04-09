//
//  AddItemService.swift
//  RentiWise
//
//  Created by You on 18/11/25.
//

import Foundation
import Supabase
import UIKit
import CoreGraphics
import CoreLocation
import ImageIO
import MobileCoreServices

private struct ListingLocation {
    let latitude: Double?
    let longitude: Double?
    let locationAddress: String?
}

protocol AddItemServicing {
    func insertItem(draft: AddItemDraft, status: ((String) -> Void)?) async throws -> ItemRow
    func updateItem(draft: AddItemDraft, status: ((String) -> Void)?) async throws -> ItemRow
}

final class AddItemService: AddItemServicing {

    private let client: SupabaseClient
    private let urlSession: URLSession
    // Ensure this matches the exact bucket ID in your Supabase project (case-sensitive).
    private let storageBucket = "itemimages"

    // Tuning knobs for upload robustness
    private let maxPixelDimension: CGFloat = 1600   // longest side in pixels after downscale
    private let jpegQuality: CGFloat = 0.7          // 0.0 - 1.0
    private let uploadMaxRetries = 3
    private let uploadInitialBackoff: TimeInterval = 0.6

    // Toggle to skip uploads and publish without images (testing only).
    // Set to false to perform real uploads.
    private let skipUploadsForTesting = false

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - Public entry
    func insertItem(draft: AddItemDraft, status: ((String) -> Void)? = nil) async throws -> ItemRow {
        try SafetyContentPolicy.validateListing(draft)

        // 1) Ensure user is logged in
        status?("Checking session…")
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            throw wrap(error, category: "Auth", hint: "Not signed in or session invalid.")
        }
        let ownerId = session.user.id.uuidString

        // 2) Upload images (optional) using resilient strategy
        let imageCount = draft.images.count
        if imageCount > 0 {
            status?("Uploading \(imageCount) image\(imageCount == 1 ? "" : "s")…")
        } else {
            status?("No images to upload.")
        }
        let imagePaths: [String]
        do {
            if skipUploadsForTesting {
                imagePaths = []
            } else {
                imagePaths = try await uploadImagesResilient(ownerId: ownerId, imagesData: draft.images, status: status)
            }
        } catch {
            throw wrap(error, category: "Storage", hint: "Image upload failed (network/bucket/policy).")
        }

        // 3) Fetch location
        status?("Saving item…")
        let listingLocation = await fetchListingLocation(for: ownerId)
        
        do {
            let item = try await insertItemRecord(
                ownerId: ownerId,
                draft: draft,
                imagePaths: imagePaths,
                listingLocation: listingLocation
            )
            status?("Done")
            return item
        } catch {
            throw wrap(error, category: "DB", hint: "Insert failed (RLS/policy/constraint).")
        }
    }

    // MARK: - Update existing item
    func updateItem(draft: AddItemDraft, status: ((String) -> Void)? = nil) async throws -> ItemRow {
        try SafetyContentPolicy.validateListing(draft)

        guard let itemId = draft.existingItemId else {
            throw wrap(NSError(domain: "AddItem.Update", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing item id for update."]), category: "Input", hint: "Draft.existingItemId is nil.")
        }

        status?("Preparing update…")

        let ownerId: String
        do {
            let session = try await client.auth.session
            ownerId = session.user.id.uuidString
        } catch {
            throw wrap(error, category: "Auth", hint: "Not signed in or session invalid.")
        }

        // Optional: if user provided new images (draft.images contains data), upload and decide how to merge.
        // Strategy: if draft.images is empty, keep existingImagePaths. If not empty, upload new and REPLACE images with new uploads.
        var finalImagePaths = draft.existingImagePaths
        if !draft.images.isEmpty {
            status?("Uploading new images…")
            do {
                let uploaded = try await uploadImagesResilient(ownerId: ownerId, imagesData: draft.images, status: status)
                finalImagePaths = uploaded
            } catch {
                throw wrap(error, category: "Storage", hint: "Image upload failed (network/bucket/policy).")
            }
        }

        status?("Updating item…")
        let listingLocation = await fetchListingLocation(for: ownerId)
        
        do {
            let declaredValue = try await updateItemRecord(
                itemId: itemId,
                ownerId: ownerId,
                draft: draft,
                imagePaths: finalImagePaths,
                listingLocation: listingLocation
            )
            status?("Updated")
            return makeLocalItemRow(
                itemId: itemId,
                ownerId: ownerId,
                draft: draft,
                imagePaths: finalImagePaths,
                declaredValue: declaredValue,
                listingLocation: listingLocation
            )
        } catch {
            throw wrap(error, category: "DB", hint: "Update failed (RLS/policy/constraint).")
        }
    }

    private func insertItemRecord(ownerId: String, draft: AddItemDraft, imagePaths: [String], listingLocation: ListingLocation?) async throws -> ItemRow {
        if ItemSchemaSupport.supportsDeclaredValue {
            do {
                let payload = ItemInsertPayload(
                    owner_id: ownerId,
                    title: draft.title,
                    description: draft.description.isEmpty ? nil : draft.description,
                    category: draft.category.isEmpty ? nil : draft.category,
                    condition: draft.condition.isEmpty ? nil : draft.condition,
                    price_per_day: draft.pricePerDay,
                    deposit_amount: draft.depositAmount,
                    declared_value: draft.declaredValue,
                    images: imagePaths,
                    is_active: draft.isActive,
                    latitude: listingLocation?.latitude,
                    longitude: listingLocation?.longitude,
                    location_address: listingLocation?.locationAddress
                )
                return try await executeInsert(payload)
            } catch {
                if ItemSchemaSupport.isMissingDeclaredValueError(error) {
                    ItemSchemaSupport.markDeclaredValueUnavailable()
                } else {
                    throw error
                }
            }
        }

        let legacyPayload = LegacyItemInsertPayload(
            owner_id: ownerId,
            title: draft.title,
            description: draft.description.isEmpty ? nil : draft.description,
            category: draft.category.isEmpty ? nil : draft.category,
            condition: draft.condition.isEmpty ? nil : draft.condition,
            price_per_day: draft.pricePerDay,
            deposit_amount: draft.depositAmount,
            images: imagePaths,
            is_active: draft.isActive,
            latitude: listingLocation?.latitude,
            longitude: listingLocation?.longitude,
            location_address: listingLocation?.locationAddress
        )
        return try await executeInsert(legacyPayload)
    }

    private func updateItemRecord(itemId: String, ownerId: String, draft: AddItemDraft, imagePaths: [String], listingLocation: ListingLocation?) async throws -> Int? {
        if ItemSchemaSupport.supportsDeclaredValue {
            do {
                let payload = ItemUpdatePayload(
                    title: draft.title,
                    description: draft.description.isEmpty ? nil : draft.description,
                    category: draft.category.isEmpty ? nil : draft.category,
                    condition: draft.condition.isEmpty ? nil : draft.condition,
                    price_per_day: draft.pricePerDay,
                    deposit_amount: draft.depositAmount,
                    declared_value: draft.declaredValue,
                    images: imagePaths,
                    is_active: draft.isActive,
                    latitude: listingLocation?.latitude,
                    longitude: listingLocation?.longitude,
                    location_address: listingLocation?.locationAddress
                )
                try await executeUpdate(payload, itemId: itemId, ownerId: ownerId)
                return draft.declaredValue
            } catch {
                if ItemSchemaSupport.isMissingDeclaredValueError(error) {
                    ItemSchemaSupport.markDeclaredValueUnavailable()
                } else {
                    throw error
                }
            }
        }

        let legacyPayload = LegacyItemUpdatePayload(
            title: draft.title,
            description: draft.description.isEmpty ? nil : draft.description,
            category: draft.category.isEmpty ? nil : draft.category,
            condition: draft.condition.isEmpty ? nil : draft.condition,
            price_per_day: draft.pricePerDay,
            deposit_amount: draft.depositAmount,
            images: imagePaths,
            is_active: draft.isActive,
            latitude: listingLocation?.latitude,
            longitude: listingLocation?.longitude,
            location_address: listingLocation?.locationAddress
        )
        try await executeUpdate(legacyPayload, itemId: itemId, ownerId: ownerId)
        return nil
    }

    private func executeInsert<Payload: Encodable>(_ payload: Payload) async throws -> ItemRow {
        let response = try await client
            .from("items")
            .insert(payload)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        return try decoder.decode(ItemRow.self, from: response.data)
    }

    private func executeUpdate<Payload: Encodable>(_ payload: Payload, itemId: String, ownerId: String) async throws {
        try await client
            .from("items")
            .update(payload)
            .eq("id", value: itemId)
            .eq("owner_id", value: ownerId)
            .execute()
    }

    // MARK: - Resilient upload orchestration
    private func uploadImagesResilient(ownerId: String, imagesData: [Data], status: ((String) -> Void)?) async throws -> [String] {
        guard !imagesData.isEmpty else { return [] }
        do {
            status?("Uploading images…")
            return try await uploadImagesIfNeeded(ownerId: ownerId, imagesData: imagesData)
        } catch {
            if isStorageRLS403(error) {
                status?("Retrying with signed uploads…")
                let paths = try await signedUploadImages(ownerId: ownerId, imagesData: imagesData, status: status)
                return paths
            } else {
                throw error
            }
        }
    }

    // MARK: - Strategy A: direct upload via SDK (primary path)
    private func uploadImagesIfNeeded(ownerId: String, imagesData: [Data]) async throws -> [String] {
        var paths: [String] = []
        let batchId = UUID().uuidString.lowercased()
        for (index, originalData) in imagesData.enumerated() {
            let preparedData = await prepareImageDataForUpload(originalData)
            let path = makeUniqueStoragePath(ownerId: ownerId, batchId: batchId, index: index)

            do {
                try await uploadWithRetry(path: path, data: preparedData)
                paths.append(path)
            } catch {
                throw error
            }
        }
        return paths
    }

    private func uploadWithRetry(path: String, data: Data) async throws {
        var attempt = 0
        var delay = uploadInitialBackoff

        while true {
            attempt += 1
            do {
                try await client
                    .storage
                    .from(storageBucket)
                    .upload(
                        path,
                        data: data,
                        options: FileOptions(contentType: "image/jpeg")
                    )
                return
            } catch {
                if isStorageConflict(error) {
                    // The first attempt may have already created the object successfully.
                    return
                }
                if isStorageRLS403(error) { throw error }
                let nsError = error as NSError
                let isTransient = (nsError.domain == NSURLErrorDomain) && (nsError.code == -1001 || nsError.code == -1005 || nsError.code == -1017)
                if attempt < uploadMaxRetries && isTransient {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                    continue
                } else {
                    throw error
                }
            }
        }
    }

    private func isStorageRLS403(_ error: Error) -> Bool {
        if let storageError = error as? StorageError {
            if storageError.statusCode == "403" { return true }
        }
        return false
    }

    private func isStorageConflict(_ error: Error) -> Bool {
        if let storageError = error as? StorageError, storageError.statusCode == "409" {
            return true
        }

        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("already exists") || message.contains("resource already exists")
    }

    // MARK: - Strategy B: Signed upload URL flow (REST)
    private func signedUploadImages(ownerId: String, imagesData: [Data], status: ((String) -> Void)?) async throws -> [String] {
        var paths: [String] = []
        let batchId = UUID().uuidString.lowercased()

        for (index, originalData) in imagesData.enumerated() {
            status?("Preparing signed upload (\(index+1)/\(imagesData.count))…")
            let preparedData = await prepareImageDataForUpload(originalData)
            let path = makeUniqueStoragePath(ownerId: ownerId, batchId: batchId, index: index)

            let signedURL = try await createSignedUploadURL(bucketId: storageBucket, objectPath: path, expiresIn: 120)
            try await putData(to: signedURL, data: preparedData, contentType: "image/jpeg")

            paths.append(path)
        }
        return paths
    }

    private func createSignedUploadURL(bucketId: String, objectPath: String, expiresIn: Int) async throws -> URL {
        let projectURL = SupabaseManager.shared.projectURL
        var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)!
        components.path = "/storage/v1/object/upload/sign/\(bucketId)"

        guard let url = components.url else {
            throw wrap(NSError(domain: "SignedUploadURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid signed upload URL path"]), category: "Storage", hint: "Bad path.")
        }

        struct Body: Encodable {
            let objectName: String
            let expiresIn: Int
        }
        let body = Body(objectName: objectPath, expiresIn: expiresIn)
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.publicAnonKey, forHTTPHeaderField: "apikey")
        let token = try await client.auth.session.accessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw wrap(NSError(domain: "SignedUploadURL", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create signed upload URL"]), category: "Storage", hint: "Check bucket id, RLS and token.")
        }

        struct Resp: Decodable { let signedUrl: String }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let finalURL = URL(string: resp.signedUrl, relativeTo: projectURL) else {
            throw wrap(NSError(domain: "SignedUploadURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad signed upload URL in response"]), category: "Storage", hint: "Response format.")
        }
        return finalURL
    }

    private func putData(to url: URL, data: Data, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw wrap(NSError(domain: "SignedUploadPUT", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "PUT failed"]), category: "Storage", hint: "Signed URL expired or invalid.")
        }
    }

    // Downscale and recompress image data to keep uploads small and stable
    private func prepareImageDataForUpload(_ data: Data) async -> Data {
        guard let image = UIImage(data: data) else {
            return data
        }

        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let scaleFactor = (maxSide > maxPixelDimension && maxSide > 0) ? (maxPixelDimension / maxSide) : 1.0
        let targetSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)

        if scaleFactor >= 1.0 {
            if let jpeg = image.jpegData(compressionQuality: jpegQuality) {
                return jpeg
            }
            return data
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let downscaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        if let jpeg = downscaled.jpegData(compressionQuality: jpegQuality) {
            return jpeg
        }
        return data
    }

    private func makeUniqueStoragePath(ownerId: String, batchId: String, index: Int) -> String {
        let milliseconds = Int(Date().timeIntervalSince1970 * 1000)
        let objectId = UUID().uuidString.lowercased()
        return "\(ownerId)/item_\(batchId)_\(milliseconds)_\(index)_\(objectId).jpg"
    }

    private func makeLocalItemRow(itemId: String, ownerId: String, draft: AddItemDraft, imagePaths: [String], declaredValue: Int?, listingLocation: ListingLocation?) -> ItemRow {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return ItemRow(
            id: itemId,
            owner_id: ownerId,
            title: draft.title,
            description: draft.description.isEmpty ? nil : draft.description,
            category: draft.category.isEmpty ? nil : draft.category,
            condition: draft.condition.isEmpty ? nil : draft.condition,
            price_per_day: draft.pricePerDay,
            deposit_amount: draft.depositAmount,
            declared_value: declaredValue,
            images: imagePaths,
            is_active: draft.isActive,
            latitude: listingLocation?.latitude,
            longitude: listingLocation?.longitude,
            location_address: listingLocation?.locationAddress,
            created_at: timestamp,
            updated_at: timestamp
        )
    }

    private func fetchListingLocation(for ownerId: String) async -> ListingLocation? {
        struct DefaultAddressRow: Decodable {
            let latitude: Double?
            let longitude: Double?
            let city: String?
            let state: String?
            let country: String?
        }

        // 1) Try the user's default address from the addresses table
        do {
            let rows: [DefaultAddressRow] = try await client
                .from("addresses")
                .select("latitude,longitude,city,state,country")
                .eq("user_id", value: ownerId)
                .order("is_default", ascending: false)
                .limit(1)
                .execute()
                .value

            if let row = rows.first,
               let lat = row.latitude, let lon = row.longitude,
               lat != 0, lon != 0 {
                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let addressText = parts.isEmpty ? nil : parts.joined(separator: ", ")
                return ListingLocation(latitude: lat, longitude: lon, locationAddress: addressText)
            }
        } catch {
            debugLog("[AddItem] Failed to fetch listing location from addresses: \(error.localizedDescription)")
        }

        // 2) Fallback: use device GPS and auto-save to addresses
        if let location = try? await AppLocationManager.shared.currentLocation() {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            // Auto-create an address row so future listings use it
            await autoSaveAddressFromGPS(userId: ownerId, latitude: lat, longitude: lon)
            return ListingLocation(latitude: lat, longitude: lon, locationAddress: nil)
        }

        debugLog("[AddItem] No location available from addresses or GPS")
        return nil
    }

    /// Saves the device GPS as the user's default address if they don't have one yet.
    /// Reverse geocodes to fill required NOT NULL columns (address_line1, city, state, postal_code).
    private func autoSaveAddressFromGPS(userId: String, latitude: Double, longitude: Double) async {
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
            // Check if address already exists
            let existing: [DefaultAddressRow] = try await client
                .from("addresses")
                .select("latitude,longitude,city,state,country")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            guard existing.isEmpty else { return }

            // Reverse geocode to fill required columns
            var city = "Chennai"
            var state = "Tamil Nadu"
            var country = "India"
            var postalCode = "600001"
            var addressLine1 = "Auto-detected location"

            let location = CLLocation(latitude: latitude, longitude: longitude)
            if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
               let p = placemarks.first {
                city = p.locality ?? p.subLocality ?? city
                state = p.administrativeArea ?? state
                country = p.country ?? country
                postalCode = p.postalCode ?? postalCode
                let parts = [p.subThoroughfare, p.thoroughfare, p.subLocality].compactMap { $0 }.joined(separator: " ")
                if !parts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    addressLine1 = parts
                } else {
                    addressLine1 = "\(city) area"
                }
            }

            let payload = AddressInsert(
                user_id: userId,
                label: "Home",
                address_line1: addressLine1,
                city: city,
                state: state,
                postal_code: postalCode,
                country: country,
                latitude: latitude,
                longitude: longitude,
                is_default: true
            )
            _ = try await client.from("addresses").insert(payload).execute()
            debugLog("[AddItem] Auto-saved GPS address: \(city), \(state)")
        } catch {
            debugLog("[AddItem] autoSaveAddressFromGPS failed: \(error.localizedDescription)")
        }
    }

    private struct DefaultAddressRow: Decodable {
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
    }

    // MARK: - Error wrapping for clearer UI
    private func wrap(_ error: Error, category: String, hint: String) -> NSError {
        let ns = error as NSError
        let composed = "\(category) error: \(ns.localizedDescription). \(hint)"
        return NSError(domain: "AddItem.Publish", code: ns.code, userInfo: [
            NSLocalizedDescriptionKey: composed
        ])
    }
}

private struct ItemUpdatePayload: Encodable {
    let title: String
    let description: String?
    let category: String?
    let condition: String?
    let price_per_day: Double
    let deposit_amount: Double
    let declared_value: Int
    let images: [String]
    let is_active: Bool
    let latitude: Double?
    let longitude: Double?
    let location_address: String?
}

private struct LegacyItemInsertPayload: Encodable {
    let owner_id: String
    let title: String
    let description: String?
    let category: String?
    let condition: String?
    let price_per_day: Double
    let deposit_amount: Double
    let images: [String]
    let is_active: Bool
    let latitude: Double?
    let longitude: Double?
    let location_address: String?
}

private struct LegacyItemUpdatePayload: Encodable {
    let title: String
    let description: String?
    let category: String?
    let condition: String?
    let price_per_day: Double
    let deposit_amount: Double
    let images: [String]
    let is_active: Bool
    let latitude: Double?
    let longitude: Double?
    let location_address: String?
}

private enum ItemSchemaSupport {
    static var supportsDeclaredValue: Bool {
        get {
            if UserDefaults.standard.object(forKey: "RW_supportsDeclaredValue") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "RW_supportsDeclaredValue")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "RW_supportsDeclaredValue")
        }
    }

    static func isMissingDeclaredValueError(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("declared_value") &&
            (message.contains("schema cache") || message.contains("column") || message.contains("items"))
    }

    static func markDeclaredValueUnavailable() {
        supportsDeclaredValue = false
    }
}
