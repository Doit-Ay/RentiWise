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

class ReturnProofViewController: UIViewController {
    
    // MARK: - Properties
    
    var request: RequestWithItem?
    /// Called on the caller when a request is successfully submitted (before dismiss).
    var onRequestSubmitted: (() -> Void)?
    private var proofMediaURLs: [URL] = []
    private var notes: String = ""
    
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
        
        // Set rental period using ACTUAL start_date and end_date from the request
        let dbFormatter = DateFormatter()
        dbFormatter.dateFormat = "yyyy-MM-dd"
        dbFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        let startStr: String
        let endStr: String
        
        if let startDate = dbFormatter.date(from: req.start_date) {
            startStr = displayFormatter.string(from: startDate)
        } else {
            startStr = req.start_date
        }
        
        if let endDate = dbFormatter.date(from: req.end_date) {
            endStr = displayFormatter.string(from: endDate)
        } else {
            endStr = req.end_date
        }
        
        rentalPeriodLabel.text = "\(startStr) – \(endStr)"
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
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 5 - proofMediaURLs.count // Max 5 total
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - API Calls
    
    private func uploadMediaToSupabase(_ mediaURL: URL) async throws -> String {
        let fileExtension = mediaURL.pathExtension.isEmpty ? "jpg" : mediaURL.pathExtension
        let fileName = "return_proof_\(UUID().uuidString).\(fileExtension)"
        let storagePath = "return-proofs/\(fileName)"
        
        guard let data = try? Data(contentsOf: mediaURL) else {
            throw NSError(domain: "ReturnProof", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to read media file."])
        }
        
        let mimeType = fileExtension.lowercased() == "mp4" ? "video/mp4" : "image/jpeg"
        
        try await SupabaseManager.shared.client.storage
            .from("return-proofs")
            .upload(storagePath, data: data, options: FileOptions(contentType: mimeType, upsert: false))
        
        print("[ReturnProof] Uploaded to Supabase Storage: \(storagePath)")
        return storagePath
    }
    
    private func submitReturnRequest(for request: RequestWithItem) async {
        do {
            // Upload all media files
            var uploadedPaths: [String] = []
            for mediaURL in proofMediaURLs {
                let path = try await uploadMediaToSupabase(mediaURL)
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
            
            // Insert into database
            // NOTE: This requires a "return_requests" table in Supabase
            let _ = try await SupabaseManager.shared.client
                .from("return_requests")
                .insert(returnData)
                .execute()
            
            await MainActor.run {
                self.submitButton.isEnabled = true
                self.onRequestSubmitted?()   // notify BookingApprovalVC instantly
                self.showAlert(title: "Success", message: "Return request submitted successfully") {
                    self.dismiss(animated: true)
                }
            }
        } catch {
            print("[ReturnProof] Error submitting return request: \(error)")
            await MainActor.run {
                self.submitButton.isEnabled = true
                self.showAlert(title: "Error", message: "Failed to submit return request. Please try again.")
            }
        }
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as! MediaCell
            cell.configure(with: proofMediaURLs[indexPath.item])
            cell.onDelete = { [weak self] in
                self?.proofMediaURLs.remove(at: indexPath.item)
                self?.mediaCollectionView.reloadData()
                self?.updateMediaCount()
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddMediaCell", for: indexPath) as! AddMediaCell
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
        fatalError("init(coder:) has not been implemented")
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
        fatalError("init(coder:) has not been implemented")
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
