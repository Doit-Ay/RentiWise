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
import ImageIO
import MobileCoreServices

protocol AddItemServicing {
    func insertItem(draft: AddItemDraft, status: ((String) -> Void)?) async throws -> ItemRow
    func updateItem(draft: AddItemDraft, status: ((String) -> Void)?) async throws -> ItemRow
}

final class AddItemService: AddItemServicing {

    private let client: SupabaseClient
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
    }

    // MARK: - Public entry
    func insertItem(draft: AddItemDraft, status: ((String) -> Void)? = nil) async throws -> ItemRow {
        // 0) Validate inputs (defence-in-depth: UI should also guard these)
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NSError(domain: "AddItemService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Item title cannot be blank. Please enter a title."])
        }
        guard draft.pricePerDay > 0 else {
            throw NSError(domain: "AddItemService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Price per day must be greater than ₹0."])
        }

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

        // 3) Build payload
        let payload = ItemInsertPayload(
            owner_id: ownerId,
            title: draft.title,
            description: draft.description.isEmpty ? nil : draft.description,
            category: draft.category.isEmpty ? nil : draft.category,
            condition: draft.condition.isEmpty ? nil : draft.condition,
            price_per_day: draft.pricePerDay,
            deposit_amount: draft.depositAmount,
            images: imagePaths,
            is_active: draft.isActive
        )

        // 4) Insert into public.items and return the created row
        status?("Saving item…")
        do {
            let response = try await client
                .from("items")
                .insert(payload)
                .select()
                .single()
                .execute()

            let decoder = JSONDecoder()
            let item = try decoder.decode(ItemRow.self, from: response.data)
            status?("Done")
            return item
        } catch {
            throw wrap(error, category: "DB", hint: "Insert failed (RLS/policy/constraint).")
        }
    }

    // MARK: - Update existing item
    func updateItem(draft: AddItemDraft, status: ((String) -> Void)? = nil) async throws -> ItemRow {
        guard let itemId = draft.existingItemId else {
            throw wrap(NSError(domain: "AddItem.Update", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing item id for update."]), category: "Input", hint: "Draft.existingItemId is nil.")
        }

        status?("Preparing update…")

        // Optional: if user provided new images (draft.images contains data), upload and decide how to merge.
        // Strategy: if draft.images is empty, keep existingImagePaths. If not empty, upload new and REPLACE images with new uploads.
        var finalImagePaths = draft.existingImagePaths
        if !draft.images.isEmpty {
            status?("Uploading new images…")
            let ownerId: String
            do {
                let session = try await client.auth.session
                ownerId = session.user.id.uuidString
            } catch {
                throw wrap(error, category: "Auth", hint: "Not signed in or session invalid.")
            }

            do {
                let uploaded = try await uploadImagesResilient(ownerId: ownerId, imagesData: draft.images, status: status)
                finalImagePaths = uploaded
            } catch {
                throw wrap(error, category: "Storage", hint: "Image upload failed (network/bucket/policy).")
            }
        }

        struct ItemUpdatePayload: Encodable {
            let title: String
            let description: String?
            let category: String?
            let condition: String?
            let price_per_day: Double
            let deposit_amount: Double
            let images: [String]
            let is_active: Bool
        }

        let payload = ItemUpdatePayload(
            title: draft.title,
            description: draft.description.isEmpty ? nil : draft.description,
            category: draft.category.isEmpty ? nil : draft.category,
            condition: draft.condition.isEmpty ? nil : draft.condition,
            price_per_day: draft.pricePerDay,
            deposit_amount: draft.depositAmount,
            images: finalImagePaths,
            is_active: draft.isActive
        )

        status?("Updating item…")
        do {
            let response = try await client
                .from("items")
                .update(payload)
                .eq("id", value: itemId)
                .select()
                .single()
                .execute()

            let decoder = JSONDecoder()
            let updated = try decoder.decode(ItemRow.self, from: response.data)
            status?("Updated")
            return updated
        } catch {
            throw wrap(error, category: "DB", hint: "Update failed (RLS/policy/constraint).")
        }
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
        for (index, originalData) in imagesData.enumerated() {
            let preparedData = await prepareImageDataForUpload(originalData)
            let filename = "item_\(Int(Date().timeIntervalSince1970))_\(index).jpg"
            let folder = ownerId
            let path = "\(folder)/\(filename)"

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

    // MARK: - Strategy B: Signed upload URL flow (REST)
    private func signedUploadImages(ownerId: String, imagesData: [Data], status: ((String) -> Void)?) async throws -> [String] {
        var paths: [String] = []
        let folder = ownerId

        for (index, originalData) in imagesData.enumerated() {
            status?("Preparing signed upload (\(index+1)/\(imagesData.count))…")
            let preparedData = await prepareImageDataForUpload(originalData)
            let filename = "item_\(Int(Date().timeIntervalSince1970))_\(index).jpg"
            let path = "\(folder)/\(filename)"

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.publicAnonKey, forHTTPHeaderField: "apikey")
        let token = try await client.auth.session.accessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
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
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
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

    // MARK: - Error wrapping for clearer UI
    private func wrap(_ error: Error, category: String, hint: String) -> NSError {
        let ns = error as NSError
        let composed = "\(category) error: \(ns.localizedDescription). \(hint)"
        return NSError(domain: "AddItem.Publish", code: ns.code, userInfo: [
            NSLocalizedDescriptionKey: composed
        ])
    }
}

