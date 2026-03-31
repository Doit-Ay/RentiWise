//
//  AddItemFirstViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit
import PhotosUI
import AVFoundation
import Supabase

private let reuseImageCell = "PhotoCell"
private let reuseAddCell   = "AddCell"

class AddItemFirstViewController: UIViewController,
                                  PHPickerViewControllerDelegate,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate,
                                  UICollectionViewDataSource,
                                  UICollectionViewDelegateFlowLayout {

    // MARK: - Permission helpers (Photos & Camera)
    private enum PhotoPermissionResult { case authorized, limited, denied }
    private enum CameraPermissionResult { case authorized, denied }

    @MainActor
    private func ensurePhotoLibraryPermission() async -> PhotoPermissionResult {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch newStatus {
            case .authorized: return .authorized
            case .limited: return .limited
            case .denied, .restricted: return .denied
            default: return .denied
            }
        @unknown default:
            return .denied
        }
    }

    @MainActor
    private func ensureCameraPermission() async -> CameraPermissionResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    @MainActor
    private func presentGoToSettingsAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        }))
        present(alert, animated: true)
    }

    @IBOutlet weak var gridContainer: UIView?
    @IBOutlet weak var continueButton: UIButton!

    private var images: [UIImage] = []
    private let maxImages = 4

    private var collectionView: UICollectionView!

    // Draft to carry data through the flow
    var draft = AddItemDraft() // made internal so ProductViewController can set

    override func viewDidLoad() {
        super.viewDidLoad()
        if title?.isEmpty ?? true { title = "Add item" }
        hidesBottomBarWhenPushed = true
        setupCollectionView()
        prefillIfEditing()
        updateContinueState()
        continueButton.addTarget(self, action: #selector(continueTapped(_:)), for: .touchUpInside)

        // Check if user has a UPI ID set; if not, show a warning banner
        Task { await checkUpiIdAndShowBanner() }
    }

    // MARK: - UPI Warning Banner

    private func checkUpiIdAndShowBanner() async {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return }
        do {
            struct UpiRow: Decodable { let upi_id: String? }
            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("upi_id")
                .eq("id", value: userId)
                .single()
                .execute()
            let row = try JSONDecoder().decode(UpiRow.self, from: resp.data)
            if let upi = row.upi_id, !upi.isEmpty { return } // UPI ID is set, do nothing
        } catch {
            // If fetch fails, still show the banner to be safe
        }
        await MainActor.run { showUpiWarningBanner() }
    }

    private func showUpiWarningBanner() {
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

        let banner = UIView()
        banner.backgroundColor = brandTeal.withAlphaComponent(0.1)
        banner.layer.borderColor = brandTeal.cgColor
        banner.layer.borderWidth = 1
        banner.layer.cornerRadius = 12
        banner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Add your UPI ID in Profile so borrowers can pay you."
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let goButton = UIButton(type: .system)
        goButton.setTitle("Go to Profile", for: .normal)
        goButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        goButton.tintColor = brandTeal
        goButton.addTarget(self, action: #selector(goToProfileTapped), for: .touchUpInside)
        goButton.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(label)
        banner.addSubview(goButton)
        view.addSubview(banner)

        // Find StepHeader dynamically (it's the first UIStackView in the main view)
        guard let stepHeader = view.subviews.first(where: { $0 is UIStackView }),
              let grid = gridContainer else { return }
              
        // Find and deactivate the existing constraint linking gridContainer.top to stepHeader.bottom
        if let existingConstraint = view.constraints.first(where: { 
            ($0.firstItem as? UIView) == grid && ($0.secondItem as? UIView) == stepHeader && $0.firstAttribute == .top
        }) {
            existingConstraint.isActive = false
        }
        
        NSLayoutConstraint.activate([
            // Pin banner below stepHeader
            banner.topAnchor.constraint(equalTo: stepHeader.bottomAnchor, constant: 16),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            
            goButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            goButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            goButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -12),
            
            // Pin gridContainer below banner
            grid.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 16)
        ])
    }

    @objc private func goToProfileTapped() {
        // Switch to Profile tab
        if let tab = tabBarController ?? (view.window?.rootViewController as? UITabBarController) {
            // Find Profile tab index (usually last tab)
            if let vcs = tab.viewControllers {
                for (i, vc) in vcs.enumerated() {
                    let root = (vc as? UINavigationController)?.viewControllers.first ?? vc
                    if root is ProfileViewController {
                        navigationController?.popToRootViewController(animated: false)
                        tab.selectedIndex = i
                        return
                    }
                }
            }
        }
    }

    private func prefillIfEditing() {
        guard draft.isEditing else { return }
        // If draft.images already contains Data (downloaded in ProductViewController), convert to UIImage for display
        if !draft.images.isEmpty {
            images = draft.images.compactMap { UIImage(data: $0) }
            collectionView?.reloadData()
        }
    }

    // MARK: - Continue
    @IBAction func continueTapped(_ sender: UIButton) {
        guard !images.isEmpty else { return }

        // Convert UIImages to JPEG data for upload later
        draft.images = images.compactMap { $0.jpegData(compressionQuality: 0.8) }

        let vc = AddItemDetailViewController(nibName: "AddItemDetailViewController", bundle: nil)
        vc.title = "Add item"
        vc.draft = draft

        guard let nav = navigationController else {
            assertionFailure("AddItemFirstViewController must be pushed inside a UINavigationController within the tab bar.")
            return
        }
        nav.pushViewController(vc, animated: true)
    }

    // MARK: - Collection setup
    private func setupCollectionView() {
        let container = gridContainer ?? view!

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self

        cv.register(PhotoCell.self, forCellWithReuseIdentifier: reuseImageCell)
        cv.register(AddCell.self, forCellWithReuseIdentifier: reuseAddCell)

        container.addSubview(cv)
        cv.translatesAutoresizingMaskIntoConstraints = false

        if container === view {
            NSLayoutConstraint.activate([
                cv.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
                cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cv.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                cv.topAnchor.constraint(equalTo: container.topAnchor),
                cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cv.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }

        collectionView = cv
    }

    // MARK: - Helpers
    private var showsAddTile: Bool { images.count < maxImages }

    private func isAddTile(indexPath: IndexPath) -> Bool {
        showsAddTile && indexPath.item == images.count
    }

    private func updateContinueState() {
        let enabled = !images.isEmpty
        continueButton?.isEnabled = enabled
        continueButton?.alpha = enabled ? 1.0 : 0.5
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count + (showsAddTile ? 1 : 0)
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isAddTile(indexPath: indexPath) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseAddCell, for: indexPath) as! AddCell
            cell.configure()
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseImageCell, for: indexPath) as! PhotoCell
            let image = images[indexPath.item]
            cell.configure(with: image)
            cell.onDeleteTapped = { [weak self] cell in
                guard let self = self,
                      let currentIndexPath = collectionView.indexPath(for: cell) else { return }
                self.removeImage(atCellIndexPath: currentIndexPath)
            }
            return cell
        }
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isAddTile(indexPath: indexPath) {
            presentAddSourceActionSheet(from: collectionView.cellForItem(at: indexPath))
        } else {
            // Optional: preview image
        }
    }

    // MARK: - Layout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let flow = collectionViewLayout as? UICollectionViewFlowLayout else {
            return CGSize(width: 150, height: 150)
        }

        if images.isEmpty {
            let side: CGFloat = 150
            return CGSize(width: side, height: side)
        }

        let insets = flow.sectionInset
        let spacing = flow.minimumInteritemSpacing
        let totalHorizontalPadding = insets.left + insets.right + spacing
        let width = collectionView.bounds.width - totalHorizontalPadding
        let tile = floor(width / 2)
        return CGSize(width: tile, height: tile)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        guard collectionViewLayout is UICollectionViewFlowLayout else {
            return .zero
        }

        var insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        if images.isEmpty {
            // Vertical centering (existing logic)
            let side: CGFloat = 200
            let availableHeight = collectionView.bounds.inset(by: collectionView.adjustedContentInset).height
            let remaining = max(0, (availableHeight - side)) / 2
            let verticalOffset: CGFloat = 150
            insets.top = max(16, remaining - verticalOffset)
            insets.bottom = max(16, remaining + verticalOffset)

            // NEW: Horizontal centering for a single 150pt cell
            let cellWidth: CGFloat = 150
            let availableWidth = collectionView.bounds.inset(by: collectionView.adjustedContentInset).width
            let horizontalPadding = max(16, (availableWidth - cellWidth) / 2)
            insets.left = horizontalPadding
            insets.right = horizontalPadding
        }
        return insets
    }

    // MARK: - Add source UI
    private func presentAddSourceActionSheet(from sourceView: UIView?) {
        guard images.count < maxImages else { return }

        let ac = UIAlertController(title: "Add Photo", message: "Choose a source", preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.presentPhotoLibrary()
        })
        ac.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            self.presentCamera()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = ac.popoverPresentationController, let sourceView = sourceView {
            pop.sourceView = sourceView
            pop.sourceRect = sourceView.bounds
        }
        present(ac, animated: true)
    }

    // MARK: - Photo Library (PHPickerViewControllerDelegate)
    private func presentPhotoLibrary() {
        Task { @MainActor in
            let permission = await ensurePhotoLibraryPermission()
            switch permission {
            case .authorized, .limited:
                var config = PHPickerConfiguration()
                config.filter = .images
                let remaining = max(0, maxImages - images.count)
                config.selectionLimit = remaining == 0 ? 0 : remaining
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true)
            case .denied:
                self.presentGoToSettingsAlert(title: "Photo Library Access Needed", message: "Please allow access to your photos to add images.")
            }
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty, images.count < maxImages else { return }

        // Load multiple images; enforce the cap while loading.
        let remainingCapacity = max(0, maxImages - images.count)
        if remainingCapacity == 0 { return }

        // We’ll collect images then update UI once.
        var newImages: [UIImage] = []
        let group = DispatchGroup()

        // Only process up to remainingCapacity results
        for provider in results.prefix(remainingCapacity).map({ $0.itemProvider }) {
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    newImages.append(image)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, !newImages.isEmpty else { return }
            // Ensure we don't exceed maxImages even if providers returned more than expected
            let allowed = max(0, self.maxImages - self.images.count)
            if allowed > 0 {
                self.images.append(contentsOf: newImages.prefix(allowed))
                self.collectionView.reloadData()
                self.updateContinueState()
            }
        }
    }

    // MARK: - Camera (UIImagePickerControllerDelegate)
    private func presentCamera() {
        Task { @MainActor in
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                self.showAlert(title: "Camera not available", message: "This device has no camera.")
                return
            }

            let permission = await ensureCameraPermission()
            switch permission {
            case .authorized:
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = self
                picker.allowsEditing = false
                self.present(picker, animated: true)
            case .denied:
                self.presentGoToSettingsAlert(title: "Camera Access Needed", message: "Please allow camera access to take photos.")
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        defer { picker.dismiss(animated: true) }
        guard images.count < maxImages else { return }

        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
            appendImage(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: - State updates
    private func appendImage(_ image: UIImage) {
        guard images.count < maxImages else { return }
        let wasFull = images.count == maxImages // false here due to guard, but keep pattern if logic changes
        images.append(image)
        if wasFull {
            collectionView.reloadData()
        } else {
            collectionView.reloadData()
        }
        updateContinueState()
    }

    // New deletion method that is resilient when the Add tile appears
    private func removeImage(atCellIndexPath indexPath: IndexPath) {
        guard indexPath.item < images.count else { return }

        // Determine if we are transitioning from 4 images (no add tile) to 3 images (add tile appears).
        let willShowAddTile = (images.count == maxImages)

        // Update data source first
        images.remove(at: indexPath.item)

        // Compute the index path for the Add tile if it's going to appear
        let addTileIndexPath = IndexPath(item: images.count, section: indexPath.section)

        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [indexPath])
            if willShowAddTile {
                collectionView.insertItems(at: [addTileIndexPath])
            }
        } completion: { _ in
            self.updateContinueState()
        }
    }

    // MARK: - Alert helper
    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

// MARK: - Cells

private final class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let deleteButton = UIButton(type: .system)

    // Pass the cell so the controller can resolve its current indexPath safely
    var onDeleteTapped: ((PhotoCell) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        let xImage = UIImage(systemName: "xmark", withConfiguration: symbolConfig)

        deleteButton.setImage(xImage, for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        deleteButton.layer.cornerRadius = 12
        deleteButton.layer.masksToBounds = true
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

        contentView.addSubview(imageView)
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6)
        ])
    }

    func configure(with image: UIImage) {
        imageView.image = image
        deleteButton.isHidden = false
    }

    @objc private func handleDelete() {
        onDeleteTapped?(self)
    }
}

private final class AddCell: UICollectionViewCell {
    private let stack = UIStackView()
    private let plusView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Clear base; we'll add frosted glass
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = false

        // Stack
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon and title
        plusView.image = UIImage(systemName: "plus")
        plusView.tintColor = .label // visible on white glass
        plusView.contentMode = .scaleAspectFit
        plusView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.text = "Add Photo"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        stack.addArrangedSubview(plusView)
        stack.addArrangedSubview(titleLabel)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        // Apply a white-tinted glass effect to the cell’s background
        // Using helper from UIExtension.applyGlassEffect
        contentView.applyGlassEffect(
            cornerRadius: 12,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.28,
            tintColorOverride: .white,   // make it look white
            tintAlpha: 0.18,             // subtle white tint over blur
            showsHighlight: true,
            highlightAlpha: 0.14
        )
    }

    func configure() {
        // Reserved for future styling if needed.
    }
}
