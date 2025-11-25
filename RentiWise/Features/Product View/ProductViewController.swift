//
//  ProductVeiwController.swift
//  ProductDetails
//
//  Created by user@48 on 13/11/25.
//

import UIKit
import Foundation

final class ProductViewController: UIViewController {
    // The selected item to display. Set this before presenting/pushing.
    var selectedItem: Item?

    // Currency formatter for rates and deposits
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    @IBOutlet weak var heroImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel?

    @IBOutlet weak var priceLabel: UILabel?
    @IBOutlet weak var distanceLabel: UILabel?
    @IBOutlet weak var ratingValueLabel: UILabel?
    @IBOutlet weak var ratingReviewsLabel: UILabel?

    // MARK: - Description card
    @IBOutlet weak var descriptionCard: UIView!
    @IBOutlet weak var descriptionTitleLabel: UILabel!
    @IBOutlet weak var descriptionBodyLabel: UILabel!

    // MARK: - Owner card
    @IBOutlet weak var ownerCard: UIView!
    @IBOutlet weak var ownerAvatarImageView: UIImageView!
    @IBOutlet weak var ownerNameLabel: UILabel!
    @IBOutlet weak var distanceRightLabel: UILabel!

    // MARK: - Deposit card
    @IBOutlet weak var depositCard: UIView!
    @IBOutlet weak var depositTitleLabel: UILabel!
    @IBOutlet weak var depositBodyLabel: UILabel!

    // MARK: - Reviews section (two sample reviews)
    @IBOutlet weak var reviewsTitleLabel: UILabel?

    // Review 1 (Alex K.)
    @IBOutlet weak var review1Card: UIView?
    @IBOutlet weak var review1DateLabel: UILabel?
    @IBOutlet weak var r1star1: UIImageView?
    @IBOutlet weak var r1star2: UIImageView?
    @IBOutlet weak var r1star3: UIImageView?
    @IBOutlet weak var r1star4: UIImageView?
    @IBOutlet weak var r1star5: UIImageView?
    @IBOutlet weak var r1AvatarImageView: UIImageView?
    @IBOutlet weak var r1NameLabel: UILabel?
    @IBOutlet weak var r1CommentLabel: UILabel?

    // Review 2 (Emily R.)
    @IBOutlet weak var review2Card: UIView?
    @IBOutlet weak var review2DateLabel: UILabel?
    @IBOutlet weak var r2star1: UIImageView?
    @IBOutlet weak var r2star2: UIImageView?
    @IBOutlet weak var r2star3: UIImageView?
    @IBOutlet weak var r2star4: UIImageView?
    @IBOutlet weak var r2star5: UIImageView?
    @IBOutlet weak var r2AvatarImageView: UIImageView?
    @IBOutlet weak var r2NameLabel: UILabel?
    @IBOutlet weak var r2CommentLabel: UILabel?

    // MARK: - Public API
    /// Call this to inject the item before navigation
    func configure(with item: Item) {
        self.selectedItem = item
    }

    // MARK: - Binding
    private func bindItemToUI() {
        guard let item = selectedItem else { return }

        // Title
        self.title = item.title
        productNameLabel?.text = item.title

        // Hero image: first image path from Supabase storage
        if let firstPath = item.images.first, let url = StorageURLBuilder.publicFileURL(for: firstPath) {
            UIImageView.loadImage(from: url) { [weak self] image in
                guard let self = self else { return }
                self.heroImageView.image = image
                self.heroImageView.contentMode = .scaleAspectFill
                self.heroImageView.clipsToBounds = true
            }
        } else {
            heroImageView.image = UIImage(systemName: "photo")
            heroImageView.tintColor = .secondaryLabel
            heroImageView.contentMode = .scaleAspectFit
        }

        // Price per day
        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        priceLabel?.text = priceText

        // Rating & reviews (placeholders until ratings schema available)
        ratingValueLabel?.text = "4.5"
        ratingReviewsLabel?.text = "(23 reviews)"

        // Distance (placeholder unless you later compute from user/location)
        distanceLabel?.text = "2.3 km"
        distanceRightLabel.text = "2.3 km"

        // Description card: show first 1–2 words from description if present
        descriptionTitleLabel.text = "Description"
        if let desc = item.description, !desc.isEmpty {
            let words = desc.split(separator: " ")
            let short: String
            if words.count <= 2 {
                short = desc
            } else {
                short = words.prefix(2).joined(separator: " ") + "…"
            }
            descriptionBodyLabel.text = short
        } else {
            descriptionBodyLabel.text = ""
        }

        // Deposit card (refundable deposit)
        depositTitleLabel.text = "Refundable Deposit"
        let deposit = NSNumber(value: item.deposit_amount)
        depositBodyLabel.text = currencyFormatter.string(from: deposit) ?? "\(item.deposit_amount)"

        // Owner detailsa (basic — uses owner_id; you can extend to fetch profile later)
        ownerNameLabel.text = "Owner"
        ownerAvatarImageView.image = UIImage(systemName: "person.circle")
        ownerAvatarImageView.tintColor = .tertiaryLabel

        // Reviews section title
        reviewsTitleLabel?.text = "Reviews"

        // Example static reviews placeholders until wired to backend reviews
        r1NameLabel?.text = "Alex K."
        r1CommentLabel?.text = "Great quality and easy pickup."
        // r1DateLabel is not defined in outlets; skip setting the date label
        for (idx, iv) in [r1star1, r1star2, r1star3, r1star4, r1star5].enumerated() {
            iv?.image = UIImage(systemName: idx < 4 ? "star.fill" : "star")
            iv?.tintColor = .systemYellow
        }

        r2NameLabel?.text = "Emily R."
        r2CommentLabel?.text = "Worked as expected. Would rent again."
        // r2DateLabel is not defined in outlets; skip setting the date label
        for (idx, iv) in [r2star1, r2star2, r2star3, r2star4, r2star5].enumerated() {
            iv?.image = UIImage(systemName: idx < 5 ? "star.fill" : "star")
            iv?.tintColor = .systemYellow
        }
    }

    // optional actions (hook later when screens exist)
    @IBAction func didTapWriteReview(_ sender: UIButton) {
        let nibName = "WriteReviewViewController"
        let writeVC: WriteReviewViewController
        
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            writeVC = WriteReviewViewController(nibName: nibName, bundle: nil)
        } else {
            writeVC = WriteReviewViewController()
        }
        writeVC.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.pushViewController(writeVC, animated: true)
        } else {
            if let popover = writeVC.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            writeVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
            self.present(writeVC, animated: true)
        }
    }

    @IBAction func didTapRentNow(_ sender: UIButton) {
        // Hook to push/present RentNow screen later
        let nibName = "RequestViewController"
        let requestVC: RequestViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            requestVC = RequestViewController(nibName: nibName, bundle: nil)
        } else {
            requestVC = RequestViewController()
        }
        requestVC.title = "Request"
        requestVC.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.pushViewController(requestVC, animated: true)
        } else {
            if let popover = requestVC.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            requestVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
            self.present(requestVC, animated: true)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Product Detail"
        bindItemToUI()
    }
}
