//
//  AddItemPublishViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPublishViewController: UIViewController {

    // Receive the draft from previous screen
    var draft: AddItemDraft = AddItemDraft()

    @IBOutlet weak var itemThumbnail: UIImageView!
    @IBOutlet weak var productName: UILabel!
    @IBOutlet weak var productRate: UILabel!
    @IBOutlet weak var productDescription: UILabel!
    @IBOutlet weak var itemViewCard: UIView!
    
    
    private let service: AddItemServicing = AddItemService()

    // Simple loader UI
    private var loader: UIAlertController?

    @IBOutlet weak var publishButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }

        // Allow description to grow vertically
        productDescription.numberOfLines = 0
        productDescription.setContentCompressionResistancePriority(.required, for: .vertical)
        productDescription.setContentHuggingPriority(.defaultLow, for: .vertical)

        // CTA label depending on mode
        if draft.isEditing {
            publishButton?.setTitle("Update", for: .normal)
        } else {
            publishButton?.setTitle("Publish", for: .normal)
        }

        // Preview using draft
        productName?.text = draft.title
        productRate?.text = draft.pricePerDay > 0 ? String(format: "₹%.2f/day", draft.pricePerDay) : ""
        productDescription?.text = draft.description
        if let firstImageData = draft.images.first, let image = UIImage(data: firstImageData) {
            itemThumbnail?.image = image
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Mirror Home's glass effect for cards
        itemViewCard.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.30,
            tintColorOverride: .white,
            tintAlpha: 0.14,
            showsHighlight: true,
            highlightAlpha: 0.15
        )
    }

    @IBAction func PublishTapped(_ sender: UIButton) {
        Task {
            if draft.isEditing {
                await update()
            } else {
                await publish()
            }
        }
    }

    private func publish() async {
        await MainActor.run { showLoader(with: "Starting…") }
        defer { Task { await MainActor.run { self.hideLoader() } } }

        do {
            let item = try await service.insertItem(draft: draft, status: { [weak self] message in
                Task { await MainActor.run { self?.updateLoader(message) } }
            })
            _ = item
            await MainActor.run {
                self.hideLoader()
                self.routeToDashboard()
            }
        } catch {
            await MainActor.run {
                self.hideLoader()
                let a = UIAlertController(title: "Publish Failed", message: error.localizedDescription, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(a, animated: true)
            }
        }
    }

    private func update() async {
        await MainActor.run { showLoader(with: "Updating…") }
        defer { Task { await MainActor.run { self.hideLoader() } } }

        do {
            let updated = try await service.updateItem(draft: draft, status: { [weak self] message in
                Task { await MainActor.run { self?.updateLoader(message) } }
            })
            _ = updated
            await MainActor.run {
                self.hideLoader()
                self.routeToDashboard()
            }
        } catch {
            await MainActor.run {
                self.hideLoader()
                let a = UIAlertController(title: "Update Failed", message: error.localizedDescription, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(a, animated: true)
            }
        }
    }

    private func showLoader(with message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isUserInteractionEnabled = false
        indicator.startAnimating()

        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])

        present(alert, animated: true)
        loader = alert
    }

    private func updateLoader(_ message: String) {
        loader?.message = message
    }

    private func hideLoader() {
        if let loader = loader {
            loader.dismiss(animated: true)
            self.loader = nil
        }
    }

    private func routeToDashboard() {
        // Instantiate Dashboard from storyboard
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        guard let dashboard = sb.instantiateViewController(withIdentifier: "DashboardListing") as? DashboardViewController else {
            // Fallback: if Dashboard storyboard ID is missing, try to recover by dismissing/popping
            if presentingViewController != nil || navigationController?.presentingViewController != nil {
                dismiss(animated: true)
            } else {
                navigationController?.popToRootViewController(animated: true)
            }
            return
        }

        // Configure Dashboard to show Listing segment without tab bar
        dashboard.title = "My Listings"
        dashboard.initialSegment = 0 // Listing
        dashboard.hidesBottomBarWhenPushed = true

        // Prefer pushing onto an existing navigation controller so we get a back button and no tab bar.
        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(dashboard, animated: true)
            return
        }

        // If we were presented modally inside a nav controller, push there
        if let presentingNav = presentingViewController as? UINavigationController {
            presentingNav.setNavigationBarHidden(false, animated: true)
            presentingNav.pushViewController(dashboard, animated: true)
            dismiss(animated: true)
            return
        }

        // Try tab bar’s selected navigation controller if available
        if let tab = (view.window?.rootViewController as? UITabBarController) ?? tabBarController,
           let nav = tab.selectedViewController as? UINavigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(dashboard, animated: true)
            // If we’re in another stack, close ourselves if needed
            if presentingViewController != nil {
                dismiss(animated: true)
            }
            return
        }

        // Final fallback: present inside a fresh navigation controller
        let nav = UINavigationController(rootViewController: dashboard)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

