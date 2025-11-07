//
//  AddItemViewController.swift
//  Rentiwise..
//
//  Created by user@48 on 05/11/25.


import UIKit
import PhotosUI
import AVFoundation   // for camera permission status

class AddItemViewController: UIViewController,
                             PHPickerViewControllerDelegate,
                             UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {

    // MARK: - Outlets
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentStack: UIStackView!

    @IBOutlet var stepCircles: [UIView]!
    @IBOutlet weak var addPhotoButton: UIButton!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Add item"
        configureNavBarShadow(false)

        styleAddPhotoButtonDashed()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        for (idx, c) in stepCircles.enumerated() {
            c.layer.cornerRadius = c.bounds.height / 2
            c.layer.masksToBounds = true
            if idx == 0 {
                c.backgroundColor = .systemTeal
                c.layer.borderWidth = 0
            } else {
                c.backgroundColor = .clear
                c.layer.borderWidth = 2
                c.layer.borderColor = UIColor.systemGray4.cgColor
            }
        }

        refreshDashedBorderPath()
    }

    // MARK: - Nav Bar
    private func configureNavBarShadow(_ show: Bool) {
        let ap = UINavigationBarAppearance()
        ap.configureWithDefaultBackground()
        ap.shadowColor = show ? UIColor.separator : .clear
        navigationItem.standardAppearance = ap
        navigationItem.scrollEdgeAppearance = ap
    }

    // MARK: - Dashed "Add Photo" button
    private func styleAddPhotoButtonDashed() {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "camera")
        config.imagePlacement = .top
        config.imagePadding = 8
        config.baseForegroundColor = .secondaryLabel
        config.attributedTitle = AttributedString(
            "Add Photo",
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ])
        )
        addPhotoButton.configuration = config

        addPhotoButton.layer.cornerRadius = 16
        addPhotoButton.layer.masksToBounds = true
        addDashedBorderLayer()
    }

    private func addDashedBorderLayer() {
        addPhotoButton.layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })

        let shape = CAShapeLayer()
        shape.name = "dashedBorder"
        shape.strokeColor = UIColor.systemGray4.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.lineDashPattern = [6, 6] // dash, gap
        shape.lineWidth = 2
        shape.path = UIBezierPath(roundedRect: addPhotoButton.bounds, cornerRadius: 16).cgPath
        shape.frame = addPhotoButton.bounds
        addPhotoButton.layer.addSublayer(shape)
    }

    private func refreshDashedBorderPath() {
        if let shape = addPhotoButton.layer.sublayers?.first(where: { $0.name == "dashedBorder" }) as? CAShapeLayer {
            shape.path = UIBezierPath(roundedRect: addPhotoButton.bounds, cornerRadius: 16).cgPath
            shape.frame = addPhotoButton.bounds
        } else {
            addDashedBorderLayer()
        }
    }

    // MARK: - Actions
    @IBAction func addPhotoTapped(_ sender: UIButton) {
        // Action sheet: choose Library or Camera
        let ac = UIAlertController(title: "Add Photo", message: "Choose a source", preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.presentPhotoLibrary()
        })
        ac.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            self.presentCamera()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover anchor
        if let pop = ac.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        present(ac, animated: true)
    }

    // MARK: - Photo Library
    private func presentPhotoLibrary() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)   // dismiss the picker, not self

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage else { return }
            DispatchQueue.main.async { self.applyPicked(image) }
        }
    }

    // MARK: - Camera
    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera not available", message: "This device has no camera.")
            return
        }

        // If previously denied/restricted, inform user. (If not determined, iOS will prompt.)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            showAlert(title: "Camera Access Denied",
                      message: "Enable camera access in Settings to take a photo.")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        defer { picker.dismiss(animated: true) }
        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
            applyPicked(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: - Common UI apply
    private func applyPicked(_ image: UIImage) {
        // Show the chosen image inside the button
        addPhotoButton.configuration = nil
        addPhotoButton.setTitle(nil, for: .normal)
        addPhotoButton.setImage(image, for: .normal)
        addPhotoButton.imageView?.contentMode = .scaleAspectFill
        addPhotoButton.clipsToBounds = true
        addPhotoButton.layer.cornerRadius = 16

        // Remove the dashed border once an image is present
        addPhotoButton.layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })
    }

    // MARK: - Alert helper
    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

