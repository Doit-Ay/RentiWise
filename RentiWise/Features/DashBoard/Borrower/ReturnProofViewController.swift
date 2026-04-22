//
//  ReturnProofViewController.swift
//  RentiWise
//
//  Created by admin67 on 2026-02-05.
//

import UIKit
import PhotosUI
import Supabase
import UniformTypeIdentifiers
import CoreGraphics

class ReturnProofViewController: UIViewController {
    
    // MARK: - Properties
    
    var request: RequestWithItem?
    /// Called on the caller when a request is successfully submitted (before dismiss).
    var onRequestSubmitted: (() -> Void)?
    private var proofMediaURLs: [URL] = []
    private var notes: String = ""
    private let proofBucket = "itemimages"
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var rentalPeriodLabel: UILabel!
    @IBOutlet weak var mediaCollectionView: UICollectionView!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var mediaCountLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        configureData()
        setupCollectionView()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set corner radius for button
        submitButton.layer.cornerRadius = 12
        submitButton.layer.masksToBounds = true
        
        // Configure text view
        notesTextView.layer.cornerRadius = 12
        notesTextView.layer.borderWidth = 1
        notesTextView.layer.borderColor = UIColor.systemGray4.cgColor
        notesTextView.layer.masksToBounds = true
        notesTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        notesTextView.delegate = self
        
        // Placeholder for text view
        if notesTextView.text.isEmpty {
            notesTextView.text = "Add notes about item condition (optional)..."
            notesTextView.textColor = .placeholderText
        }
        
        updateMediaCount()
    }
    
    private func configureData() {
        guard let req = request else { return }
        
        // Set item name
        itemNameLabel.text = req.items?.title ?? "Item"
        
        // Set rental period
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let startText = parser.date(from: req.start_date).map { formatter.string(from: $0) } ?? req.start_date
        let endText = parser.date(from: req.end_date).map { formatter.string(from: $0) } ?? req.end_date
        rentalPeriodLabel.text = "\(startText) - \(endText)"
    }
    
    private func setupCollectionView() {
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        mediaCollectionView.register(MediaCell.self, forCellWithReuseIdentifier: "MediaCell")
        mediaCollectionView.register(AddMediaCell.self, forCellWithReuseIdentifier: "AddMediaCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 120)
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        mediaCollectionView.collectionViewLayout = layout
    }
    
    private func updateMediaCount() {
        mediaCountLabel.text = "\(proofMediaURLs.count) media selected"
        submitButton.isEnabled = !proofMediaURLs.isEmpty
        submitButton.alpha = proofMediaURLs.isEmpty ? 0.5 : 1.0
    }
    
    // MARK: - Actions
    
    @IBAction func addMediaButtonTapped(_ sender: UIButton) {
        presentMediaPicker()
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard !proofMediaURLs.isEmpty,
              let req = request else {
            showAlert(title: "Error", message: "Please add at least one photo or video as proof")
            return
        }
        
        // Disable button to prevent double-tap
        submitButton.isEnabled = false
        
        Task {
            await submitReturnRequest(for: req)
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    // MARK: - Media Picker
    
    private func presentMediaPicker() {
        let remaining = 5 - proofMediaURLs.count
        guard remaining > 0 else {
            showAlert(title: "Maximum Reached", message: "You can add up to 5 photos.")
            return
        }

        let sheet = UIAlertController(title: "Add Photo", message: nil, preferredStyle: .actionSheet)

        // Camera option (only if available on device)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.openCamera()
            })
        }

        // Photo library option
        sheet.addAction(UIAlertAction(title: "Choose from Library", style: .default) { [weak self] _ in
            self?.openPhotoLibrary()
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover support
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = mediaCollectionView
            popover.sourceRect = CGRect(x: mediaCollectionView.bounds.midX, y: mediaCollectionView.bounds.midY, width: 0, height: 0)
        }

        present(sheet, animated: true)
    }

    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func openPhotoLibrary() {
        let remaining = 5 - proofMediaURLs.count
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = remaining
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - API Calls
    
    private func uploadMediaToSupabase(_ mediaURL: URL, requestId: String) async throws -> String {
        let fileExtension = mediaURL.pathExtension.isEmpty ? "jpg" : mediaURL.pathExtension.lowercased()
        let objectPath = "return-proofs/\(requestId)/\(UUID().uuidString).\(fileExtension)"
        let originalData = try Data(contentsOf: mediaURL)
        let preparedData = await prepareMediaForUpload(data: originalData, sourceURL: mediaURL)
        let contentType = contentType(for: mediaURL)

        do {
            try await SupabaseManager.shared.client
                .storage
                .from(proofBucket)
                .upload(
                    objectPath,
                    data: preparedData,
                    options: FileOptions(contentType: contentType)
                )
        } catch {
            if isStorageForbidden(error) {
                let signedURL = try await createSignedUploadURL(objectPath: objectPath, expiresIn: 120)
                try await putData(to: signedURL, data: preparedData, contentType: contentType)
            } else {
                throw error
            }
        }

        return objectPath
    }
    
    private func submitReturnRequest(for request: RequestWithItem) async {
        do {
            // Upload all media files
            var uploadedPaths: [String] = []
            for mediaURL in proofMediaURLs {
                let path = try await uploadMediaToSupabase(mediaURL, requestId: request.id)
                uploadedPaths.append(path)
            }
            
            // Create return request struct
            struct ReturnRequest: Encodable {
                let request_id: String
                let proof_media: [String]
                let notes: String
                let status: String
                let created_at: String
            }
            
            let returnData = ReturnRequest(
                request_id: request.id,
                proof_media: uploadedPaths,
                notes: notes,
                status: "pending",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            let _ = try await SupabaseManager.shared.client
                .from("return_requests")
                .insert(returnData)
                .execute()
            
            await MainActor.run {
                self.submitButton.isEnabled = true
                self.onRequestSubmitted?()   // notify BookingApprovalVC instantly

                // Track analytics & notify lender
                AnalyticsService.shared.trackSubRequestSubmitted(requestId: request.id, type: "return")
                NotificationService.shared.notifyNewSubRequest(
                    requestId: request.id,
                    itemTitle: request.items?.title ?? "Item",
                    type: "return"
                )

                self.showAlert(title: "Success", message: "Return request submitted successfully") {
                    self.dismiss(animated: true)
                }
            }
        } catch {
            debugLog("[ReturnProof] Error submitting return request: \(error)")
            await MainActor.run {
                self.submitButton.isEnabled = true
                self.showAlert(title: "Error", message: "Failed to submit return request. Please try again.")
            }
        }
    }

    private func isStorageForbidden(_ error: Error) -> Bool {
        (error as? StorageError)?.statusCode == "403"
    }

    private func createSignedUploadURL(objectPath: String, expiresIn: Int) async throws -> URL {
        let projectURL = SupabaseManager.shared.projectURL
        var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)!
        components.path = "/storage/v1/object/upload/sign/\(proofBucket)"

        guard let url = components.url else {
            throw NSError(domain: "ReturnProof.Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL."])
        }

        struct Body: Encodable {
            let objectName: String
            let expiresIn: Int
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.publicAnonKey, forHTTPHeaderField: "apikey")
        let token = try await SupabaseManager.shared.client.auth.session.accessToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(objectName: objectPath, expiresIn: expiresIn))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "ReturnProof.Upload", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Could not create an upload URL for return proof media."])
        }

        struct SignedUploadResponse: Decodable {
            let signedUrl: String
        }

        let signedUpload = try JSONDecoder().decode(SignedUploadResponse.self, from: data)
        guard let finalURL = URL(string: signedUpload.signedUrl, relativeTo: projectURL) else {
            throw NSError(domain: "ReturnProof.Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid signed upload URL returned by storage."])
        }

        return finalURL
    }

    private func putData(to url: URL, data: Data, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "ReturnProof.Upload", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Return proof upload failed."])
        }
    }

    private func prepareMediaForUpload(data: Data, sourceURL: URL) async -> Data {
        guard let type = UTType(filenameExtension: sourceURL.pathExtension.lowercased()), type.conforms(to: .image) else {
            return data
        }

        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 1600
        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let scaleFactor = (maxSide > maxDimension && maxSide > 0) ? (maxDimension / maxSide) : 1.0

        let targetSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        if scaleFactor >= 1.0 {
            return image.jpegData(compressionQuality: 0.72) ?? data
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let downscaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return downscaled.jpegData(compressionQuality: 0.72) ?? data
    }

    private func contentType(for mediaURL: URL) -> String {
        guard let type = UTType(filenameExtension: mediaURL.pathExtension.lowercased()) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }
    
    // MARK: - Helpers
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension ReturnProofViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Add notes about item condition (optional)..."
            textView.textColor = .placeholderText
        } else {
            notes = textView.text
        }
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension ReturnProofViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return proofMediaURLs.count + 1 // +1 for add button
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < proofMediaURLs.count {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as? MediaCell else {
                assertionFailure("Could not dequeue MediaCell")
                return UICollectionViewCell()
            }
            cell.configure(with: proofMediaURLs[indexPath.item])
            cell.onDelete = { [weak self] in
                guard let self else { return }
                guard indexPath.item < self.proofMediaURLs.count else { return }
                self.proofMediaURLs.remove(at: indexPath.item)
                self.mediaCollectionView.reloadData()
                self.updateMediaCount()
            }
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddMediaCell", for: indexPath) as? AddMediaCell else {
                assertionFailure("Could not dequeue AddMediaCell")
                return UICollectionViewCell()
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == proofMediaURLs.count {
            presentMediaPicker()
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ReturnProofViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else { return }
        
        for result in results {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                if let url = url {
                    // Copy to temp directory
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    
                    DispatchQueue.main.async {
                        self?.proofMediaURLs.append(tempURL)
                        self?.mediaCollectionView.reloadData()
                        self?.updateMediaCount()
                    }
                }
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)

extension ReturnProofViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.85) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        try? data.write(to: tempURL)

        proofMediaURLs.append(tempURL)
        mediaCollectionView.reloadData()
        updateMediaCount()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - MediaCell

class MediaCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let deleteButton = UIButton()
    var onDelete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray6
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = .red
        deleteButton.layer.cornerRadius = 12
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        contentView.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with url: URL) {
        if let image = UIImage(contentsOfFile: url.path) {
            imageView.image = image
        }
    }
    
    @objc private func deleteButtonTapped() {
        onDelete?()
    }
}

// MARK: - AddMediaCell

class AddMediaCell: UICollectionViewCell {
    private let iconView = UIImageView()
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray6
        
        iconView.image = UIImage(systemName: "plus.circle.fill")
        iconView.tintColor = UIColor(red: 0.365, green: 0.663, blue: 0.714, alpha: 1.0)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        label.text = "Add Media"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }
}
