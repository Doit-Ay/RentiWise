//
//  AddItemPublishViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit
import Supabase

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
        // Phone verification gate — must be verified to list items
        Task {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                await self.runPublishFlow(sender)
                return
            }
            let isPhoneVerified = await PhoneVerificationService.shared.isPhoneVerified(userId: userId)
            if !isPhoneVerified {
                await MainActor.run {
                    let phoneVC = PhoneVerificationViewController()
                    phoneVC.onVerificationComplete = { [weak self] in
                        self?.dismiss(animated: true) {
                            guard let self else { return }
                            self.PublishTapped(sender)
                        }
                    }
                    let nav = UINavigationController(rootViewController: phoneVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
                return
            }
            await self.runPublishFlow(sender)
        }
    }

    private func runPublishFlow(_ sender: UIButton) async {
        await MainActor.run {
            // VALIDATION: ensure required fields are filled before submitting
            let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty {
                let alert = UIAlertController(title: "Missing Title",
                                              message: "Please enter a title for your listing.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            if draft.pricePerDay <= 0 {
                let alert = UIAlertController(title: "Invalid Price",
                                              message: "Price per day must be greater than ₹0.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            Task {
                if self.draft.isEditing {
                    await self.update()
                } else {
                    await self.checkFreeTierAndPublish()
                }
            }
        }
    }

    private func checkFreeTierAndPublish() async {
        do {
            let isPro = await IAPManager.shared.isProUser()
            if !isPro {
                guard let userId = await SupabaseManager.shared.currentUserId() else {
                    await publish()
                    return
                }
                let resp = try await SupabaseManager.shared.client
                    .from("items")
                    .select("id", head: true, count: .exact)
                    .eq("owner_id", value: userId)
                    .execute()
                let count = resp.count ?? 0
                if count >= 3 {
                    await MainActor.run {
                        let upgradeVC = UpgradeProViewController()
                        upgradeVC.hidesBottomBarWhenPushed = true
                        upgradeVC.onSubscribed = { [weak self] in
                            Task { await self?.publish() }
                        }
                        self.navigationController?.pushViewController(upgradeVC, animated: true)
                    }
                    return
                }
            }
        } catch {
            debugLog("[AddItem] Free tier check error: \(error)")
        }
        await publish()
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
                self.routeToHome()
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
                self.routeToHome()
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

    private func routeToHome() {
        // Pop to HomeViewController if it's already in the nav stack
        if let nav = navigationController {
            if let homeVC = nav.viewControllers.first(where: { $0 is HomeViewController }) {
                nav.popToViewController(homeVC, animated: true)
                return
            }
            nav.popToRootViewController(animated: true)
            return
        }
        // Switch to the Home tab if available
        if let tab = tabBarController ?? (view.window?.rootViewController as? UITabBarController) {
            tab.selectedIndex = 0
            return
        }
        // Final fallback
        dismiss(animated: true)
    }
}

