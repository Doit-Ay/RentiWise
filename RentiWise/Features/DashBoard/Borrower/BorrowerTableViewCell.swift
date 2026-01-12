//
//  BorrowerTableViewCell
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import UIKit

class BorrowerTableViewCell: UITableViewCell {

    @IBOutlet weak var borrowerItemImage: UIImageView!
    @IBOutlet weak var borrowerItemName: UILabel!
    @IBOutlet weak var borrowerItemRate: UILabel!
    @IBOutlet weak var borrowerItemDistance: UILabel!
    @IBOutlet weak var borrowerItemOwnerName: UILabel!

    // Single solid card container
    private let cardBackground = UIView()
    private var didInstallCardConstraints = false
    private var imageLoadTask: URLSessionDataTask?

    // Toggle shadow on/off if you prefer a completely flat card
    private let showsShadow: Bool = true

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        // Keep cell transparent; only the card draws
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        borrowerItemImage?.contentMode = .scaleAspectFill
        borrowerItemImage?.clipsToBounds = true
        borrowerItemImage?.layer.cornerRadius = 12

        installCardBackgroundIfNeeded()
        applyRequestStyleCardShadow()
    }

    private func installCardBackgroundIfNeeded() {
        guard !didInstallCardConstraints else { return }
        didInstallCardConstraints = true

        cardBackground.removeFromSuperview()
        cardBackground.translatesAutoresizingMaskIntoConstraints = false

        // Solid card fill that matches system background (no blur/tint)
        cardBackground.backgroundColor = .systemBackground

        // Rounded card that clips its content
        cardBackground.layer.cornerRadius = 16
        cardBackground.clipsToBounds = false

        // Insert the card behind content
        contentView.insertSubview(cardBackground, at: 0)

        // 16pt insets so the card “floats” from the edges
        let inset: CGFloat = 16
        NSLayoutConstraint.activate([
            cardBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            cardBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            cardBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            cardBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -inset)
        ])
    }

    private func applyRequestStyleCardShadow() {
        guard showsShadow else {
            cardBackground.layer.masksToBounds = true
            cardBackground.layer.shadowOpacity = 0
            return
        }
        // Stronger, softer shadow to match Requests page
        cardBackground.layer.masksToBounds = false
        cardBackground.layer.shadowColor = UIColor.black.cgColor
        cardBackground.layer.shadowOpacity = 0.22
        cardBackground.layer.shadowRadius = 12
        cardBackground.layer.shadowOffset = CGSize(width: 0, height: 6)

        // Optional: rasterize for smoother scrolling
        cardBackground.layer.shouldRasterize = true
        cardBackground.layer.rasterizationScale = UIScreen.main.scale
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep radius and shadow path consistent
        let r: CGFloat = 16
        cardBackground.layer.cornerRadius = r
        if showsShadow {
            cardBackground.layer.shadowPath = UIBezierPath(roundedRect: cardBackground.bounds, cornerRadius: r).cgPath
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil

        borrowerItemImage?.image = nil
        borrowerItemName?.text = nil
        borrowerItemRate?.text = nil
        borrowerItemDistance?.text = nil
        borrowerItemOwnerName?.text = nil

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        cardBackground.backgroundColor = .systemBackground
    }

    // MARK: - Configure with full Item
    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        borrowerItemName?.text = item.title
        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        borrowerItemRate?.text = priceText
        borrowerItemDistance?.text = "1.4 km"
        borrowerItemOwnerName?.text = "By —"

        if let firstPath = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: firstPath) {
            setImage(from: url)
        } else {
            borrowerItemImage?.image = UIImage(systemName: "photo")
            borrowerItemImage?.tintColor = .secondaryLabel
            borrowerItemImage?.contentMode = .scaleAspectFit
        }
    }

    // MARK: - Configure with ItemLite (used by MyRentals)
    func configure(with lite: ItemLite, currencyFormatter: NumberFormatter) {
        borrowerItemName?.text = lite.title
        let amount = NSNumber(value: lite.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(lite.price_per_day)") + " / day"
        borrowerItemRate?.text = priceText
        borrowerItemDistance?.text = "1.4 km"
        borrowerItemOwnerName?.text = "By —"

        if let firstPath = lite.images.first,
           let url = StorageURLBuilder.publicFileURL(for: firstPath) {
            setImage(from: url)
        } else {
            borrowerItemImage?.image = UIImage(systemName: "photo")
            borrowerItemImage?.tintColor = .secondaryLabel
            borrowerItemImage?.contentMode = .scaleAspectFit
        }
    }

    // MARK: - Configure with RequestWithItem (borrower requests)
    func configure(with request: RequestWithItem, currencyFormatter: NumberFormatter) {
        // Title: prefer joined item title, fallback to item_id
        borrowerItemName?.text = request.items?.title ?? request.item_id

        // Price or date range
        if let p = request.items?.price_per_day {
            let amount = NSNumber(value: p)
            borrowerItemRate?.text = (currencyFormatter.string(from: amount) ?? "\(p)") + " / day"
        } else {
            // No price available -> show date range
            let sql = DateFormatter()
            sql.calendar = Calendar(identifier: .gregorian)
            sql.timeZone = TimeZone(secondsFromGMT: 0)
            sql.dateFormat = "yyyy-MM-dd"

            let display = DateFormatter()
            display.calendar = Calendar(identifier: .gregorian)
            display.timeZone = .current
            display.dateFormat = "d MMM yyyy"

            if let s = sql.date(from: request.start_date),
               let e = sql.date(from: request.end_date) {
                borrowerItemRate?.text = "\(display.string(from: s)) — \(display.string(from: e))"
            } else {
                borrowerItemRate?.text = "—"
            }
        }

        // Status: use the ownerName label slot for status display
        borrowerItemOwnerName?.text = request.status.capitalized

        // Distance placeholder
        borrowerItemDistance?.text = "1.4 km"

        // Image: from joined item images
        if let path = request.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            setImage(from: url)
        } else {
            borrowerItemImage?.image = UIImage(systemName: "photo")
            borrowerItemImage?.tintColor = .secondaryLabel
            borrowerItemImage?.contentMode = .scaleAspectFit
        }
    }

    // MARK: - Image loading
    private func setImage(from url: URL) {
        imageLoadTask?.cancel()

        if let cached = BorrowerImageCache.shared.image(forKey: url.absoluteString) {
            borrowerItemImage?.image = cached
            borrowerItemImage?.contentMode = .scaleAspectFill
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        imageLoadTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else { return }
            BorrowerImageCache.shared.setImage(image, forKey: url.absoluteString)
            DispatchQueue.main.async {
                self.borrowerItemImage?.image = image
                self.borrowerItemImage?.contentMode = .scaleAspectFill
            }
        }
        imageLoadTask?.resume()
    }
}

private final class BorrowerImageCache {
    static let shared = BorrowerImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func setImage(_ img: UIImage, forKey key: String) { cache.setObject(img, forKey: key as NSString) }
}
