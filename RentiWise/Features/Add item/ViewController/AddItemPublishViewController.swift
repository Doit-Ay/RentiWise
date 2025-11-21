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

    private let service: AddItemServicing = AddItemService()

    // Simple loader UI
    private var loader: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }

        // Optionally show a preview using draft
        productName?.text = draft.title
        productRate?.text = draft.pricePerDay > 0 ? String(format: "₹%.2f/day", draft.pricePerDay) : ""
        productDescription?.text = draft.description
        if let firstImageData = draft.images.first, let image = UIImage(data: firstImageData) {
            itemThumbnail?.image = image
        }
    }

    @IBAction func PublishTapped(_ sender: UIButton) {
        Task { await publish() }
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
        // Existing routing logic
        guard let tabBar = (view.window?.rootViewController as? UITabBarController)
                ?? navigationController?.tabBarController
                ?? tabBarController
        else {
            if presentingViewController != nil || navigationController?.presentingViewController != nil {
                dismiss(animated: true)
            } else {
                navigationController?.popToRootViewController(animated: true)
            }
            return
        }

        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        let dashboard = sb.instantiateViewController(withIdentifier: "DashboardListing")
        dashboard.hidesBottomBarWhenPushed = false

        let dashboardTabIndex = 1
        if dashboardTabIndex < (tabBar.viewControllers?.count ?? 0) {
            tabBar.selectedIndex = dashboardTabIndex
        }

        if let nav = tabBar.selectedViewController as? UINavigationController {
            nav.setViewControllers([dashboard], animated: true)
        } else if let selectedVC = tabBar.selectedViewController {
            let nav = UINavigationController(rootViewController: dashboard)
            nav.modalPresentationStyle = .fullScreen
            var vcs = tabBar.viewControllers ?? []
            if dashboardTabIndex < vcs.count {
                vcs[dashboardTabIndex] = nav
                tabBar.setViewControllers(vcs, animated: false)
                tabBar.selectedIndex = dashboardTabIndex
            } else {
                selectedVC.present(nav, animated: true)
            }
        }
    }
}
