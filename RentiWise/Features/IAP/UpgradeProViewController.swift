//
//  UpgradeProViewController.swift
//  RentiWise
//
//  Shown when a free user tries to publish more than 3 listings.
//  Displays Lender Pro benefits and subscription CTA.
//

import UIKit
import StoreKit

final class UpgradeProViewController: UIViewController {

    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var subscribeButton: UIButton!

    var onSubscribed: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lender Pro"
        view.backgroundColor = .systemBackground
        setupUI()
        Task { await IAPManager.shared.fetchProducts() }
    }

    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])

        // Icon
        let crownIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        crownIcon.tintColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.translatesAutoresizingMaskIntoConstraints = false
        crownIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        contentStack.addArrangedSubview(crownIcon)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Unlock Lender Pro"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        contentStack.addArrangedSubview(titleLabel)

        // Subtitle
        let subtitle = UILabel()
        subtitle.text = "You've reached the free limit of 3 listings."
        subtitle.font = .systemFont(ofSize: 16)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        contentStack.addArrangedSubview(subtitle)

        // Benefits card
        let benefitsCard = UIView()
        benefitsCard.backgroundColor = .secondarySystemBackground
        benefitsCard.layer.cornerRadius = 16
        benefitsCard.translatesAutoresizingMaskIntoConstraints = false

        let benefitsStack = UIStackView()
        benefitsStack.axis = .vertical
        benefitsStack.spacing = 16
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false

        let benefits = [
            ("infinity", "Unlimited Listings", "List as many items as you want"),
            ("chart.bar.fill", "Analytics Dashboard", "See views, clicks, and earnings"),
            ("star.fill", "Priority Support", "Get help faster from our team"),
            ("bolt.fill", "Early Access", "Try new features before everyone"),
        ]

        for (icon, title, desc) in benefits {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .top

            let iconView = UIImageView(image: UIImage(systemName: icon))
            iconView.tintColor = brandTeal
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2

            let titleLbl = UILabel()
            titleLbl.text = title
            titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)

            let descLbl = UILabel()
            descLbl.text = desc
            descLbl.font = .systemFont(ofSize: 14)
            descLbl.textColor = .secondaryLabel
            descLbl.numberOfLines = 0

            textStack.addArrangedSubview(titleLbl)
            textStack.addArrangedSubview(descLbl)

            row.addArrangedSubview(iconView)
            row.addArrangedSubview(textStack)
            benefitsStack.addArrangedSubview(row)
        }

        benefitsCard.addSubview(benefitsStack)
        NSLayoutConstraint.activate([
            benefitsStack.topAnchor.constraint(equalTo: benefitsCard.topAnchor, constant: 20),
            benefitsStack.leadingAnchor.constraint(equalTo: benefitsCard.leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: benefitsCard.trailingAnchor, constant: -16),
            benefitsStack.bottomAnchor.constraint(equalTo: benefitsCard.bottomAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(benefitsCard)

        // Price
        let priceLabel = UILabel()
        priceLabel.text = "₹99/month"
        priceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        priceLabel.textColor = brandTeal
        priceLabel.textAlignment = .center
        contentStack.addArrangedSubview(priceLabel)

        // Subscribe button
        subscribeButton = UIButton(type: .system)
        subscribeButton.setTitle("Subscribe Now", for: .normal)
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        subscribeButton.backgroundColor = brandTeal
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 14
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        subscribeButton.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(subscribeButton)

        // Maybe Later
        let laterButton = UIButton(type: .system)
        laterButton.setTitle("Maybe Later", for: .normal)
        laterButton.titleLabel?.font = .systemFont(ofSize: 16)
        laterButton.setTitleColor(.secondaryLabel, for: .normal)
        laterButton.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(laterButton)
    }

    // MARK: - Actions
    @objc private func subscribeTapped() {
        guard let product = IAPManager.shared.product(for: IAPManager.lenderProProductId) else {
            showAlert(title: "Unavailable", message: "Product not available. Please try again later.")
            return
        }
        subscribeButton.isEnabled = false
        subscribeButton.setTitle("Processing...", for: .normal)

        Task {
            do {
                let success = try await IAPManager.shared.purchase(product)
                await MainActor.run {
                    subscribeButton.isEnabled = true
                    subscribeButton.setTitle("Subscribe Now", for: .normal)
                    if success {
                        showAlert(title: "Welcome to Pro! 🎉", message: "You now have unlimited listings.") { [weak self] in
                            self?.onSubscribed?()
                            self?.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    subscribeButton.isEnabled = true
                    subscribeButton.setTitle("Subscribe Now", for: .normal)
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func laterTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true)
    }
}
