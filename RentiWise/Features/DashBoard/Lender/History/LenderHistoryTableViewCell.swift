//
//  LenderHistoryTableViewCell.swift
//  RentiWise
//
//  Created by admin99 on 20/11/25.
//

import UIKit

class LenderHistoryTableViewCell: UITableViewCell {

    @IBOutlet weak var itemImageHistory: UIImageView!
    @IBOutlet weak var itemNameHistory: UILabel!
    @IBOutlet weak var itemRateHistory: UILabel!
    @IBOutlet weak var itemBorrowerName: UILabel!

    // Card background (glass) container
    private let cardBackground = UIView()
    private var didInstallCardConstraints = false

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none

        // Make the cell itself transparent so the table’s grouped background shows between cards
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        // Image styling to match other cards
        itemImageHistory?.contentMode = .scaleAspectFill
        itemImageHistory?.clipsToBounds = true
        itemImageHistory?.layer.cornerRadius = 12

        installCardBackgroundIfNeeded()
    }

    private func installCardBackgroundIfNeeded() {
        guard !didInstallCardConstraints else { return }
        didInstallCardConstraints = true

        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.backgroundColor = .clear
        cardBackground.layer.cornerRadius = 16
        cardBackground.layer.masksToBounds = false

        // Insert at the back so the existing outlets appear above it
        contentView.insertSubview(cardBackground, at: 0)

        // Match spacing with other cards
        let inset: CGFloat = 16
        NSLayoutConstraint.activate([
            cardBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            cardBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            cardBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            cardBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -inset)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Apply the same “whiter” glass and shadow used elsewhere
        cardBackground.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.30,
            tintColorOverride: .white,
            tintAlpha: 0.14,
            showsHighlight: true,
            highlightAlpha: 0.18
        )

        // Shadow tuned like Listing cell
        cardBackground.layer.shadowColor = UIColor.black.cgColor
        cardBackground.layer.shadowOpacity = 0.18
        cardBackground.layer.shadowRadius = 12
        cardBackground.layer.shadowOffset = CGSize(width: 0, height: 8)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        itemImageHistory?.image = nil
        itemNameHistory?.text = nil
        itemRateHistory?.text = nil
        itemBorrowerName?.text = nil

        // Keep backgrounds consistent
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardBackground.backgroundColor = .clear
    }
}
