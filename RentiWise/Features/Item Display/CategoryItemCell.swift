// CategoryItemCell.swift
// RentiWise

import UIKit

final class CategoryItemCell: UITableViewCell {

    @IBOutlet weak var itemimage: UIImageView!
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var itemRate: UILabel!
    @IBOutlet weak var itemDistance: UILabel!
    @IBOutlet weak var wishlist: UIImageView!
    @IBOutlet weak var itemRating: UILabel!
    @IBOutlet weak var itemViewCard: UIView?

    // Controls the spacing around the card
    private let verticalInset: CGFloat = 5
    private let horizontalInset: CGFloat = 16

    private var addedInsetConstraints = false

    // Card appearance
    private let cornerRadius: CGFloat = 20

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Card styling (rounded, no custom border)
        itemViewCard?.layer.cornerRadius = cornerRadius
        itemViewCard?.layer.masksToBounds = true
        itemViewCard?.backgroundColor = UIColor(red: 0x70/255.0,
                                                green: 0xA7/255.0,
                                                blue: 0xB4/255.0,
                                                alpha: 1.0)

      
        // Image styling
        itemimage?.layer.cornerRadius = 12
        itemimage?.clipsToBounds = true
        itemimage?.contentMode = .scaleAspectFill

        // Add insets around the card by constraining it inside contentView
        applyCardInsetsIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure constraints are in place if the NIB/storyboard was missing them
        applyCardInsetsIfNeeded()
    }

    private func applyCardInsetsIfNeeded() {
        guard let card = itemViewCard, !addedInsetConstraints else { return }
        card.translatesAutoresizingMaskIntoConstraints = false

        // Remove any conflicting constraints that pin the card edge-to-edge
        let toRemove = contentView.constraints.filter { constraint in
            let involvesCard = (constraint.firstItem as? UIView) === card || (constraint.secondItem as? UIView) === card
            return involvesCard
        }
        contentView.removeConstraints(toRemove)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalInset),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalInset),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalInset),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalInset),
        ])

        addedInsetConstraints = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        itemimage?.image = nil
    }

    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        itemName?.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        let currency = currencyFormatter.string(from: amount) ?? "\(item.price_per_day)"
        itemRate?.text = "\(currency) / day"

        itemDistance?.text = ""
        itemRating?.text = ""

        // If your bucket is private and you need signed URLs:
        if let path = item.images.first {
            itemimage?.image = nil
            Task { [weak self] in
                do {
                    // IMPORTANT: Use your actual bucket name (e.g., "itemimages" per your SQL)
                    let url = try await StorageService().signedURL(bucket: "itemimages", path: path, expiresIn: 3600)
                    UIImageView.loadImage(from: url) { image in
                        self?.itemimage?.image = image
                    }
                } catch {
                    self?.itemimage?.image = nil
                }
            }
        } else {
            itemimage?.image = nil
        }

        // If your bucket is public instead, comment the block above and use:
        /*
        if let path = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            itemimage?.image = nil
            UIImageView.loadImage(from: url) { [weak self] image in
                self?.itemimage?.image = image
            }
        } else {
            itemimage?.image = nil
        }
        */
    }
}

// MARK: - Lightweight remote image loading
private extension UIImageView {
    func setImage(from url: URL) {
        UIImageView.loadImage(from: url) { [weak self] image in
            self?.image = image
        }
    }
}
