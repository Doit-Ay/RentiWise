//
//  LenderListingTableViewCell.swift
//  RentiWise
//
//  Created by admin99 on 20/11/25.
//

import UIKit

final class LenderListingTableViewCell: UITableViewCell {

    @IBOutlet weak var itemImageListing: UIImageView!
    @IBOutlet weak var itemNameListing: UILabel!
    @IBOutlet weak var itemRateListing: UILabel!
    @IBOutlet weak var itemRatingListing: UILabel!
    @IBOutlet weak var listingcard: UIView!
    // Simple in-flight loader task to avoid image flicker when reused
    private var imageLoadTask: URLSessionDataTask?

    // Glass card background (programmatic container)
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

        // Optional styling
        itemImageListing.contentMode = .scaleAspectFill
        itemImageListing.clipsToBounds = true
        itemImageListing.layer.cornerRadius = 12

        // Install card background once
        installCardBackgroundIfNeeded()
    }

    private func installCardBackgroundIfNeeded() {
        guard !didInstallCardConstraints else { return }
        didInstallCardConstraints = true

        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.backgroundColor = .clear
        cardBackground.layer.cornerRadius = 16
        cardBackground.layer.masksToBounds = false

        // Insert the background at the back so existing outlets remain visible above it
        contentView.insertSubview(cardBackground, at: 0)

        // Use 16pt inset around the card so rows have 16pt spacing between them
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
        // Make the glass “whiter” and the shadow deeper so it pops from the background
        cardBackground.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.38,
            tintColorOverride: .white,
            tintAlpha: 0.24,
            showsHighlight: true,
            highlightAlpha: 0.20
        )
        cardBackground.layer.shadowColor = UIColor.black.cgColor
        cardBackground.layer.shadowOpacity = 0.18
        cardBackground.layer.shadowRadius = 12
        cardBackground.layer.shadowOffset = CGSize(width: 0, height: 8)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        itemImageListing.image = nil
        itemNameListing.text = nil
        itemRateListing.text = nil
        itemRatingListing.text = nil

        // Keep backgrounds consistent
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardBackground.backgroundColor = .clear
    }

    /// Configure with your Item model and a currency formatter
    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        itemNameListing.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        itemRateListing.text = priceText

        // No rating field in your schema; show a placeholder or hide
        itemRatingListing.text = "★ 4.5 (23)" // TODO: replace when rating data exists

        // Load first image if present
        if let firstPath = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: firstPath) {
            setImage(from: url)
        } else {
            itemImageListing.image = UIImage(systemName: "photo")
            itemImageListing.tintColor = .secondaryLabel
            itemImageListing.contentMode = .scaleAspectFit
        }
    }

    // MARK: - Lightweight async image loading
    private func setImage(from url: URL) {
        imageLoadTask?.cancel()

        if let cached = ImageCache.shared.image(forKey: url.absoluteString) {
            itemImageListing.image = cached
            itemImageListing.contentMode = .scaleAspectFill
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        imageLoadTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else { return }

            ImageCache.shared.setImage(image, forKey: url.absoluteString)

            DispatchQueue.main.async {
                self.itemImageListing.image = image
                self.itemImageListing.contentMode = .scaleAspectFill
            }
        }
        imageLoadTask?.resume()
    }
}

// Simple shared image cache
private final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func setImage(_ image: UIImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}
