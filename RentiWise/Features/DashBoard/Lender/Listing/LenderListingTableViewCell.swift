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

    // Simple in-flight loader task to avoid image flicker when reused
    private var imageLoadTask: URLSessionDataTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        // Optional styling
        itemImageListing.contentMode = .scaleAspectFill
        itemImageListing.clipsToBounds = true
        itemImageListing.layer.cornerRadius = 8
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        itemImageListing.image = nil
        itemNameListing.text = nil
        itemRateListing.text = nil
        itemRatingListing.text = nil
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
        // Cancel any previous load
        imageLoadTask?.cancel()

        // Basic in-memory cache by URL
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
                // Ensure the cell hasn’t been reused for another image
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

