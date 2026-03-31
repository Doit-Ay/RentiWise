//
//  BoostItemViewController.swift
//  RentiWise
//
//  Lets a lender boost their item to the top of its category for 7 days.
//  Accessed from the "…" menu on own-item mode in ProductViewController.
//

import UIKit
import StoreKit
import Supabase

final class BoostItemViewController: UIViewController {

    var itemId: String = ""
    var itemTitle: String = ""
    var categoryName: String = ""

    var onBoosted: (() -> Void)?

    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    private var boostButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Boost Listing"
        view.backgroundColor = .systemBackground
        setupUI()
        Task { await IAPManager.shared.fetchProducts() }
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])

        // Bolt icon
        let boltIcon = UIImageView(image: UIImage(systemName: "bolt.fill"))
        boltIcon.tintColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        boltIcon.contentMode = .scaleAspectFit
        boltIcon.translatesAutoresizingMaskIntoConstraints = false
        boltIcon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(boltIcon)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Boost \"\(itemTitle)\""
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // Description
        let descLabel = UILabel()
        let cat = categoryName.isEmpty ? "its category" : categoryName
        descLabel.text = "Your item will appear at the top of \(cat) for 7 days. More visibility means faster rentals!"
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        stack.addArrangedSubview(descLabel)

        // Benefits
        let benefitsCard = UIView()
        benefitsCard.backgroundColor = .secondarySystemBackground
        benefitsCard.layer.cornerRadius = 16

        let benefitsStack = UIStackView()
        benefitsStack.axis = .vertical
        benefitsStack.spacing = 12
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false

        let perks = [
            ("arrow.up.circle.fill", "Appears first in search results"),
            ("eye.fill", "Up to 5x more views"),
            ("bolt.circle.fill", "⚡ Boosted badge on your listing"),
        ]
        for (icon, text) in perks {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            let iv = UIImageView(image: UIImage(systemName: icon))
            iv.tintColor = brandTeal
            iv.widthAnchor.constraint(equalToConstant: 22).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 22).isActive = true
            iv.contentMode = .scaleAspectFit
            let lbl = UILabel()
            lbl.text = text
            lbl.font = .systemFont(ofSize: 15)
            row.addArrangedSubview(iv)
            row.addArrangedSubview(lbl)
            benefitsStack.addArrangedSubview(row)
        }

        benefitsCard.addSubview(benefitsStack)
        NSLayoutConstraint.activate([
            benefitsStack.topAnchor.constraint(equalTo: benefitsCard.topAnchor, constant: 16),
            benefitsStack.leadingAnchor.constraint(equalTo: benefitsCard.leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: benefitsCard.trailingAnchor, constant: -16),
            benefitsStack.bottomAnchor.constraint(equalTo: benefitsCard.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(benefitsCard)

        // Price
        let priceLabel = UILabel()
        priceLabel.text = "₹29"
        priceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = brandTeal
        priceLabel.textAlignment = .center
        stack.addArrangedSubview(priceLabel)

        // Boost button
        boostButton = UIButton(type: .system)
        boostButton.setTitle("⚡ Boost Now", for: .normal)
        boostButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        boostButton.backgroundColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        boostButton.setTitleColor(.white, for: .normal)
        boostButton.layer.cornerRadius = 14
        boostButton.translatesAutoresizingMaskIntoConstraints = false
        boostButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        boostButton.addTarget(self, action: #selector(boostTapped), for: .touchUpInside)
        stack.addArrangedSubview(boostButton)
    }

    @objc private func boostTapped() {
        guard let product = IAPManager.shared.product(for: IAPManager.boostProductId) else {
            let alert = UIAlertController(title: "Unavailable", message: "Product not available.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        boostButton.isEnabled = false
        boostButton.setTitle("Processing...", for: .normal)

        Task {
            do {
                let success = try await IAPManager.shared.purchase(product)
                // If purchase succeeded, also boost this specific item
                if success {
                    struct BoostUpdate: Encodable {
                        let is_boosted: Bool
                        let boost_expires_at: String
                    }
                    let update = BoostUpdate(
                        is_boosted: true,
                        boost_expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600))
                    )
                    try await SupabaseManager.shared.client
                        .from("items")
                        .update(update)
                        .eq("id", value: itemId)
                        .execute()
                }
                await MainActor.run {
                    boostButton.isEnabled = true
                    boostButton.setTitle("⚡ Boost Now", for: .normal)
                    if success {
                        let alert = UIAlertController(title: "Boosted! ⚡", message: "Your item will appear at the top for 7 days.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Awesome", style: .default) { [weak self] _ in
                            self?.onBoosted?()
                            self?.navigationController?.popViewController(animated: true)
                        })
                        present(alert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    boostButton.isEnabled = true
                    boostButton.setTitle("⚡ Boost Now", for: .normal)
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}
