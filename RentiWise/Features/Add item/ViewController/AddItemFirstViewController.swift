//
//  AddItemFirstViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit
import PhotosUI
import AVFoundation

private let reuseImageCell = "PhotoCell"
private let reuseAddCell   = "AddCell"

class AddItemFirstViewController: UIViewController,
                                  PHPickerViewControllerDelegate,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate,
                                  UICollectionViewDataSource,
                                  UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var gridContainer: UIView?
    @IBOutlet weak var continueButton: UIButton!

    private var images: [UIImage] = []
    private let maxImages = 4

    private var collectionView: UICollectionView!

    // Draft to carry data through the flow
    private var draft = AddItemDraft()

    override func viewDidLoad() {
        super.viewDidLoad()
        if title?.isEmpty ?? true { title = "Add item" }
        hidesBottomBarWhenPushed = true
        setupCollectionView()
        updateContinueState()
        continueButton.addTarget(self, action: #selector(continueTapped(_:)), for: .touchUpInside)
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
            cell.onDeleteTapped = { [weak self] in
                guard let self = self else { return }
                self.removeImage(at: indexPath)
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
            let side: CGFloat = 200
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
            let side: CGFloat = 200
            let availableHeight = collectionView.bounds.inset(by: collectionView.adjustedContentInset).height
            let remaining = max(0, (availableHeight - side)) / 2
            let verticalOffset: CGFloat = 150
            insets.top = max(16, remaining - verticalOffset)
            insets.bottom = max(16, remaining + verticalOffset)
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
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard images.count < maxImages else { return }

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self.appendImage(image)
            }
        }
    }

    // MARK: - Camera (UIImagePickerControllerDelegate)
    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera not available", message: "This device has no camera.")
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            showAlert(title: "Camera Access Denied", message: "Enable camera access in Settings to take a photo.")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
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
        images.append(image)
        collectionView.reloadData()
        updateContinueState()
    }

    private func removeImage(at indexPath: IndexPath) {
        guard indexPath.item < images.count else { return }
        images.remove(at: indexPath.item)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [indexPath])
        } completion: { _ in
            self.collectionView.reloadData()
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

    var onDeleteTapped: (() -> Void)?

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
        onDeleteTapped?()
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
        contentView.backgroundColor = .systemGray6
        contentView.layer.cornerRadius = 12
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.layer.borderWidth = 1
        contentView.layer.masksToBounds = true

        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        plusView.image = UIImage(systemName: "plus")
        plusView.tintColor = .secondaryLabel
        plusView.contentMode = .scaleAspectFit
        plusView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.text = "Add Photo"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        stack.addArrangedSubview(plusView)
        stack.addArrangedSubview(titleLabel)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure() {
        // Reserved for future styling if needed.
    }
}
