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
        // 1) Ensure user is logged in
        status?("Checking session…")
        print("[AddItem] Step 1: Fetching auth session...")
        let session: Session
        do {
            session = try await client.auth.session
            print("[AddItem] Auth OK. user.id=\(session.user.id.uuidString)")
            print("[AddItem] Access token length: \((try? await client.auth.session).map { $0.accessToken.count } ?? 0)")
        } catch {
            print("[AddItem][Auth][Error] \(error)")
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
        print("[AddItem] Step 2: Upload images count=\(imageCount)")
        let imagePaths: [String]
        do {
            if skipUploadsForTesting {
                print("[AddItem] Test mode: skipping image uploads. Inserting with images=[].")
                imagePaths = []
            } else {
                imagePaths = try await uploadImagesResilient(ownerId: ownerId, imagesData: draft.images, status: status)
                print("[AddItem] Uploads finished. paths=\(imagePaths)")
            }
        } catch {
            print("[AddItem][Storage][Error] \(error)")
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
        print("[AddItem] Step 3: Inserting row into items...")
        do {
            let response = try await client
                .from("items")
                .insert(payload)
                .select()
                .single()
                .execute()

            let statusCode = response.response.statusCode
            print("[AddItem] Insert response status=\(statusCode)")

            if let bodyStr = String(data: response.data, encoding: .utf8) {
                print("[AddItem] Insert response body: \(bodyStr)")
            } else {
                print("[AddItem] Insert response body: <non-utf8>")
            }

            let decoder = JSONDecoder()
            let item = try decoder.decode(ItemRow.self, from: response.data)
            print("[AddItem] Step 4: Decode OK. item.id=\(item.id)")
            status?("Done")
            return item
        } catch {
            print("[AddItem][DB][InsertError] \(error)")
            dump(error)
            throw wrap(error, category: "DB", hint: "Insert failed (RLS/policy/constraint).")
        }
    }

    // MARK: - Resilient upload orchestration
    private func uploadImagesResilient(ownerId: String, imagesData: [Data], status: ((String) -> Void)?) async throws -> [String] {
        guard !imagesData.isEmpty else {
            print("[AddItem][Storage] No images to upload. Skipping.")
            return []
        }

        // Strategy A: normal upload (with retries)
        do {
            status?("Uploading images…")
            return try await uploadImagesIfNeeded(ownerId: ownerId, imagesData: imagesData)
        } catch {
            // If it’s 403 from Storage, try Strategy B
            if isStorageRLS403(error) {
                print("[AddItem][Storage] Strategy A failed with 403. Trying signed upload (strategy B)…")
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
        print("[AddItem][Storage] Project URL=\(SupabaseManager.shared.projectURL.absoluteString)")
        print("[AddItem][Storage] Starting uploads to bucket=\(storageBucket)")
        var paths: [String] = []
        for (index, originalData) in imagesData.enumerated() {
            let preparedData = await prepareImageDataForUpload(originalData)
            let filename = "item_\(Int(Date().timeIntervalSince1970))_\(index).jpg"
            let folder = ownerId
            let path = "\(folder)/\(filename)"
            print("[AddItem][Storage] (\(index+1)/\(imagesData.count)) Upload start: path=\(path) size=\(preparedData.count) bytes")
            print("[AddItem][Storage] auth.uid (ownerId)=\(ownerId) firstFolder=\(path.split(separator: "/").first ?? Substring(""))")

            do {
                try await uploadWithRetry(path: path, data: preparedData)
                print("[AddItem][Storage] (\(index+1)/\(imagesData.count)) Upload finished: path=\(path)")
                paths.append(path)
            } catch {
                print("[AddItem][Storage][PerFileError] path=\(path) error=\(error)")
                throw error
            }
        }
        print("[AddItem][Storage] All uploads completed.")
        return paths
    }

    // Retry wrapper for transient network errors (-1001 timeout, -1005 connection lost, -1017 cannot parse response)
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
                // If it’s a Storage 403, bubble up immediately so Strategy B can engage
                if isStorageRLS403(error) {
                    throw error
                }

                let nsError = error as NSError
                let code = nsError.code
                // NSURLErrorTimedOut = -1001, NSURLErrorNetworkConnectionLost = -1005, NSURLErrorCannotParseResponse = -1017
                let isTransient = (nsError.domain == NSURLErrorDomain) && (code == -1001 || code == -1005 || code == -1017)
                if attempt < uploadMaxRetries && isTransient {
                    let delayString = String(format: "%.1f", delay)
                    print("[AddItem][Storage][Retry] attempt \(attempt) failed with \(nsError.localizedDescription). Retrying in \(delayString)s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                    continue
                } else {
                    print("[AddItem][Storage][Retry] giving up after \(attempt) attempts. error=\(nsError)")
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

            print("[AddItem][SignedUpload] Creating signed upload URL for \(path)")
            let signedURL = try await createSignedUploadURL(bucketId: storageBucket, objectPath: path, expiresIn: 120)

            print("[AddItem][SignedUpload] PUT data to signed URL: \(signedURL.absoluteString)")
            try await putData(to: signedURL, data: preparedData, contentType: "image/jpeg")

            paths.append(path)
            print("[AddItem][SignedUpload] Done \(index+1)/\(imagesData.count)")
        }
        return paths
    }

    private func createSignedUploadURL(bucketId: String, objectPath: String, expiresIn: Int) async throws -> URL {
        // POST /storage/v1/object/upload/sign/{bucketId}
        let projectURL = SupabaseManager.shared.projectURL
        var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)!
        components.path = "/storage/v1/object/upload/sign/\(bucketId)"

        guard let url = components.url else {
            throw wrap(NSError(domain: "SignedUploadURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid signed upload URL path"]), category: "Storage", hint: "Bad path.")
        }

        print("[AddItem][SignedUploadURL] Project URL=\(projectURL.absoluteString) bucketId=\(bucketId) requestURL=\(url.absoluteString)")

        struct Body: Encodable {
            let objectName: String
            let expiresIn: Int
        }
        let body = Body(objectName: objectPath, expiresIn: expiresIn)
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth headers
        request.setValue(SupabaseManager.shared.publicAnonKey, forHTTPHeaderField: "apikey")
        let token = try await client.auth.session.accessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw wrap(NSError(domain: "SignedUploadURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"]), category: "Storage", hint: "Network.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[AddItem][SignedUploadURL] Error status=\(http.statusCode) body=\(bodyStr)")
            throw wrap(NSError(domain: "SignedUploadURL", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create signed upload URL (\(http.statusCode))"]), category: "Storage", hint: "Check bucket id, RLS and token.")
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

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw wrap(NSError(domain: "SignedUploadPUT", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"]), category: "Storage", hint: "Network.")
        }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: respData, encoding: .utf8) ?? "<non-utf8>"
            print("[AddItem][SignedUpload][PUT] Error status=\(http.statusCode) body=\(body)")
            throw wrap(NSError(domain: "SignedUploadPUT", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "PUT failed (\(http.statusCode))"]), category: "Storage", hint: "Signed URL expired or invalid.")
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
