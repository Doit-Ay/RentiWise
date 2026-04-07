//
//  HandoffProofViewController.swift
//  RentiWise
//
//  Reusable photo-proof capture screen for rental handoff (pickup) and return.
//  Presented after OTP verification or from the lender dashboard.
//
//  Saves timestamped photos + notes to the `handoff_proofs` table in Supabase.
//

import UIKit
import PhotosUI
import Supabase
import UniformTypeIdentifiers
import CoreLocation

// MARK: - Configuration Types

enum HandoffProofType: String, Codable {
    case pickup
    case `return`

    var displayTitle: String {
        switch self {
        case .pickup:  return "Pickup Proof"
        case .return:  return "Return Proof"
        }
    }

    var promptTitle: String {
        switch self {
        case .pickup:  return "Document Item Condition at Pickup"
        case .return:  return "Document Item Condition at Return"
        }
    }

    var promptSubtitle: String {
        switch self {
        case .pickup:  return "Take clear photos of the item before handing it over. This protects both parties in case of disputes."
        case .return:  return "Take clear photos of the item being returned. This protects both parties in case of disputes."
        }
    }
}

enum HandoffProofRole: String, Codable {
    case lender
    case borrower

    var displayName: String {
        switch self {
        case .lender:   return "Lender"
        case .borrower: return "Borrower"
        }
    }
}

// MARK: - View Controller

final class HandoffProofViewController: UIViewController {

    // MARK: - Configuration (set before presenting)

    var requestId: String = ""
    var proofType: HandoffProofType = .pickup
    var role: HandoffProofRole = .lender
    var itemTitle: String?
    /// Called after proof is successfully submitted.
    var onProofSubmitted: (() -> Void)?

    // MARK: - Private State

    private var selectedMediaURLs: [URL] = []
    private let storageBucket = "itemimages"
    private let maxPhotos = 5

    // MARK: - Brand Colors

    private let brandTeal = UIColor(red: 93/255.0, green: 169/255.0, blue: 182/255.0, alpha: 1.0)

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let headerIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let photoSectionLabel = UILabel()
    private let photoCountLabel = UILabel()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 110, height: 110)
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(HandoffMediaCell.self, forCellWithReuseIdentifier: HandoffMediaCell.reuseID)
        cv.register(HandoffAddMediaCell.self, forCellWithReuseIdentifier: HandoffAddMediaCell.reuseID)
        return cv
    }()

    private let notesSectionLabel = UILabel()
    private let notesTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 15)
        tv.layer.cornerRadius = 12
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.systemGray4.cgColor
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        tv.isScrollEnabled = false
        return tv
    }()
    private let notesPlaceholder = "Describe the item's current condition (optional)..."
    private var isPlaceholderActive = true

    private let submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 14
        btn.layer.masksToBounds = true
        return btn
    }()

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Skip for Now", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        return btn
    }()

    private let loadingOverlay = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = proofType.displayTitle
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        buildUI()
        configureContent()
        updateSubmitState()
    }

    // MARK: - UI Construction

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Header icon
        let iconName = proofType == .pickup ? "camera.viewfinder" : "checkmark.shield"
        headerIcon.image = UIImage(systemName: iconName)
        headerIcon.tintColor = brandTeal
        headerIcon.contentMode = .scaleAspectFit
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        headerIcon.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let iconContainer = UIView()
        iconContainer.addSubview(headerIcon)
        headerIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor).isActive = true
        headerIcon.topAnchor.constraint(equalTo: iconContainer.topAnchor).isActive = true
        headerIcon.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor).isActive = true

        // Title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Photo section header
        let photoHeaderRow = UIStackView()
        photoHeaderRow.axis = .horizontal
        photoHeaderRow.alignment = .center
        photoSectionLabel.text = "Photos"
        photoSectionLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        photoSectionLabel.textColor = .label
        photoCountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        photoCountLabel.textColor = .secondaryLabel
        photoCountLabel.textAlignment = .right
        photoHeaderRow.addArrangedSubview(photoSectionLabel)
        photoHeaderRow.addArrangedSubview(UIView()) // spacer
        photoHeaderRow.addArrangedSubview(photoCountLabel)

        // Collection view height
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Notes section header
        notesSectionLabel.text = "Condition Notes"
        notesSectionLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        notesSectionLabel.textColor = .label

        // Notes text view
        notesTextView.delegate = self
        notesTextView.text = notesPlaceholder
        notesTextView.textColor = .placeholderText

        // Submit button
        submitButton.backgroundColor = brandTeal
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        // Skip button
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        // Add to stack
        let topSpacer = UIView()
        topSpacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        contentStack.addArrangedSubview(topSpacer)
        contentStack.addArrangedSubview(iconContainer)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        let divider1 = makeDivider()
        contentStack.addArrangedSubview(divider1)
        contentStack.addArrangedSubview(photoHeaderRow)
        contentStack.addArrangedSubview(collectionView)

        let divider2 = makeDivider()
        contentStack.addArrangedSubview(divider2)
        contentStack.addArrangedSubview(notesSectionLabel)
        contentStack.addArrangedSubview(notesTextView)

        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        contentStack.addArrangedSubview(bottomSpacer)
        contentStack.addArrangedSubview(submitButton)
        contentStack.addArrangedSubview(skipButton)

        let endSpacer = UIView()
        endSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        contentStack.addArrangedSubview(endSpacer)

        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        // Loading overlay
        buildLoadingOverlay()

        // Keyboard dismiss tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
    }

    private func configureContent() {
        titleLabel.text = proofType.promptTitle
        subtitleLabel.text = proofType.promptSubtitle
        submitButton.setTitle("Submit \(proofType.displayTitle)", for: .normal)

        if let itemTitle, !itemTitle.isEmpty {
            titleLabel.text = "\(proofType.promptTitle)\n\(itemTitle)"
        }
    }

    private func makeDivider() -> UIView {
        let d = UIView()
        d.backgroundColor = .separator
        d.translatesAutoresizingMaskIntoConstraints = false
        d.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return d
    }

    private func buildLoadingOverlay() {
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        loadingOverlay.isHidden = true

        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.color = brandTeal
        loadingSpinner.hidesWhenStopped = true

        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Uploading proof..."
        loadingLabel.font = .systemFont(ofSize: 15, weight: .medium)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center

        loadingOverlay.addSubview(loadingSpinner)
        loadingOverlay.addSubview(loadingLabel)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -14),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
        ])
    }

    // MARK: - State

    private func updateSubmitState() {
        let hasPhotos = !selectedMediaURLs.isEmpty
        submitButton.isEnabled = hasPhotos
        submitButton.alpha = hasPhotos ? 1.0 : 0.5
        photoCountLabel.text = "\(selectedMediaURLs.count)/\(maxPhotos)"
    }

    private func setLoading(_ loading: Bool) {
        loadingOverlay.isHidden = !loading
        if loading {
            loadingSpinner.startAnimating()
            view.bringSubviewToFront(loadingOverlay)
        } else {
            loadingSpinner.stopAnimating()
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        confirmDismissIfNeeded()
    }

    @objc private func skipTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func submitTapped() {
        guard !selectedMediaURLs.isEmpty else {
            showAlert(title: "No Photos", message: "Please add at least one photo as proof.")
            return
        }
        guard !requestId.isEmpty else {
            showAlert(title: "Error", message: "Missing request context. Please try again.")
            return
        }

        submitButton.isEnabled = false
        setLoading(true)

        Task {
            await submitProof()
        }
    }

    private func confirmDismissIfNeeded() {
        guard !selectedMediaURLs.isEmpty else {
            dismiss(animated: true)
            return
        }

        let alert = UIAlertController(
            title: "Discard Photos?",
            message: "You have unsaved photos. Are you sure you want to leave?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Photo Picker

    private func presentPhotoPicker() {
        let remaining = maxPhotos - selectedMediaURLs.count
        guard remaining > 0 else {
            showAlert(title: "Maximum Reached", message: "You can add up to \(maxPhotos) photos.")
            return
        }

        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = remaining

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Upload & Submit

    private func submitProof() async {
        do {
            var uploadedPaths: [String] = []

            for (index, mediaURL) in selectedMediaURLs.enumerated() {
                await MainActor.run {
                    self.loadingLabel.text = "Uploading photo \(index + 1) of \(self.selectedMediaURLs.count)..."
                }

                let path = try await uploadMedia(mediaURL)
                uploadedPaths.append(path)
            }

            await MainActor.run {
                self.loadingLabel.text = "Saving proof record..."
            }

            let notes = isPlaceholderActive ? nil : notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNotes = (notes?.isEmpty ?? true) ? nil : notes

            try await saveProofRecord(mediaPaths: uploadedPaths, notes: finalNotes)

            await MainActor.run {
                self.setLoading(false)
                self.submitButton.isEnabled = true
                self.showSuccessAndDismiss()
            }
        } catch {
            debugLog("[HandoffProof] Submit failed: \(error)")
            await MainActor.run {
                self.setLoading(false)
                self.submitButton.isEnabled = true
                self.showAlert(title: "Upload Failed", message: "Could not upload proof. Please check your connection and try again.")
            }
        }
    }

    private func uploadMedia(_ mediaURL: URL) async throws -> String {
        let fileExtension = mediaURL.pathExtension.isEmpty ? "jpg" : mediaURL.pathExtension.lowercased()
        let objectPath = "handoff-proofs/\(requestId)/\(UUID().uuidString).\(fileExtension)"

        let originalData = try Data(contentsOf: mediaURL)
        let preparedData = prepareImageForUpload(data: originalData, sourceURL: mediaURL)
        let mimeType = resolveContentType(for: mediaURL)

        do {
            try await SupabaseManager.shared.client
                .storage
                .from(storageBucket)
                .upload(
                    objectPath,
                    data: preparedData,
                    options: FileOptions(contentType: mimeType)
                )
        } catch {
            // Fallback: attempt signed upload if direct upload fails (storage RLS)
            if isStorageForbidden(error) {
                let signedURL = try await createSignedUploadURL(objectPath: objectPath)
                try await putData(to: signedURL, data: preparedData, contentType: mimeType)
            } else {
                throw error
            }
        }

        return objectPath
    }

    private func saveProofRecord(mediaPaths: [String], notes: String?) async throws {
        struct HandoffProofInsert: Encodable {
            let request_id: String
            let proof_type: String
            let role: String
            let media_paths: [String]
            let notes: String?
        }

        let record = HandoffProofInsert(
            request_id: requestId,
            proof_type: proofType.rawValue,
            role: role.rawValue,
            media_paths: mediaPaths,
            notes: notes
        )

        _ = try await SupabaseManager.shared.client
            .from("handoff_proofs")
            .insert(record)
            .execute()
    }

    // MARK: - Image Processing

    private func prepareImageForUpload(data: Data, sourceURL: URL) -> Data {
        guard let type = UTType(filenameExtension: sourceURL.pathExtension.lowercased()),
              type.conforms(to: .image) else {
            return data
        }
        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 1600
        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let scaleFactor = (maxSide > maxDimension && maxSide > 0) ? (maxDimension / maxSide) : 1.0

        if scaleFactor >= 1.0 {
            return image.jpegData(compressionQuality: 0.72) ?? data
        }

        let targetSize = CGSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let downscaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return downscaled.jpegData(compressionQuality: 0.72) ?? data
    }

    private func resolveContentType(for url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }

    // MARK: - Storage Helpers

    private func isStorageForbidden(_ error: Error) -> Bool {
        (error as? StorageError)?.statusCode == "403"
    }

    private func createSignedUploadURL(objectPath: String) async throws -> URL {
        let projectURL = SupabaseManager.shared.projectURL
        var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)!
        components.path = "/storage/v1/object/upload/sign/\(storageBucket)"

        guard let url = components.url else {
            throw HandoffProofError.invalidUploadURL
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
        request.httpBody = try JSONEncoder().encode(Body(objectName: objectPath, expiresIn: 120))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HandoffProofError.uploadSigningFailed
        }

        struct SignedUploadResponse: Decodable { let signedUrl: String }
        let signedUpload = try JSONDecoder().decode(SignedUploadResponse.self, from: data)
        guard let finalURL = URL(string: signedUpload.signedUrl, relativeTo: projectURL) else {
            throw HandoffProofError.invalidUploadURL
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
            throw HandoffProofError.uploadFailed
        }
    }

    // MARK: - Success / Alerts

    private func showSuccessAndDismiss() {
        let alert = UIAlertController(
            title: "Proof Submitted ✓",
            message: "Your \(proofType == .pickup ? "pickup" : "return") photos have been saved successfully.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.onProofSubmitted?()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Errors

private enum HandoffProofError: Error, LocalizedError {
    case invalidUploadURL
    case uploadSigningFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL:    return "Could not construct the upload URL."
        case .uploadSigningFailed: return "The server rejected the upload request."
        case .uploadFailed:        return "File upload failed. Please try again."
        }
    }
}

// MARK: - UITextViewDelegate

extension HandoffProofViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if isPlaceholderActive {
            textView.text = ""
            textView.textColor = .label
            isPlaceholderActive = false
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = notesPlaceholder
            textView.textColor = .placeholderText
            isPlaceholderActive = true
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension HandoffProofViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // +1 for the "Add" cell (only if under limit)
        return selectedMediaURLs.count + (selectedMediaURLs.count < maxPhotos ? 1 : 0)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < selectedMediaURLs.count {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HandoffMediaCell.reuseID, for: indexPath) as? HandoffMediaCell else {
                assertionFailure("Could not dequeue HandoffMediaCell")
                return UICollectionViewCell()
            }
            cell.configure(with: selectedMediaURLs[indexPath.item])
            cell.onDelete = { [weak self] in
                guard let self else { return }
                guard indexPath.item < self.selectedMediaURLs.count else { return }
                self.selectedMediaURLs.remove(at: indexPath.item)
                self.collectionView.reloadData()
                self.updateSubmitState()
            }
            return cell
        } else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: HandoffAddMediaCell.reuseID, for: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item >= selectedMediaURLs.count {
            presentPhotoPicker()
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension HandoffProofViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        for result in results {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
                guard let self, let url else { return }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "\(UUID().uuidString).\(url.pathExtension)"
                )
                try? FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    self.selectedMediaURLs.append(tempURL)
                    self.collectionView.reloadData()
                    self.updateSubmitState()
                }
            }
        }
    }
}

// MARK: - Media Cells

private final class HandoffMediaCell: UICollectionViewCell {
    static let reuseID = "HandoffMediaCell"
    var onDelete: (() -> Void)?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var deleteButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray6

        contentView.addSubview(imageView)
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray6

        contentView.addSubview(imageView)
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        onDelete = nil
    }

    func configure(with url: URL) {
        imageView.image = UIImage(contentsOfFile: url.path)
    }

    @objc private func deleteTapped() { onDelete?() }
}

private final class HandoffAddMediaCell: UICollectionViewCell {
    static let reuseID = "HandoffAddMediaCell"

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
        iv.tintColor = UIColor(red: 93/255.0, green: 169/255.0, blue: 182/255.0, alpha: 1.0)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.text = "Add Photo"
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.backgroundColor = .systemGray6

        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.backgroundColor = .systemGray6

        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
}

// MARK: - Presentation Helper

extension HandoffProofViewController {
    /// Factory method to create and present the handoff proof capture flow.
    static func present(
        from presenter: UIViewController,
        requestId: String,
        proofType: HandoffProofType,
        role: HandoffProofRole,
        itemTitle: String? = nil,
        onSubmitted: (() -> Void)? = nil
    ) {
        let vc = HandoffProofViewController()
        vc.requestId = requestId
        vc.proofType = proofType
        vc.role = role
        vc.itemTitle = itemTitle
        vc.onProofSubmitted = onSubmitted

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(nav, animated: true)
    }
}
