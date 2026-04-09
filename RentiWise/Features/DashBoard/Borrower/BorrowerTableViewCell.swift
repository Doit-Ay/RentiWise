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
    private var distanceWorkItem: Task<Void, Never>?
    private var currentImageURL: URL?

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

        cardBackground.backgroundColor = .systemBackground
        cardBackground.layer.cornerRadius = 16
        cardBackground.clipsToBounds = false

        contentView.insertSubview(cardBackground, at: 0)

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
        cardBackground.layer.masksToBounds = false
        cardBackground.layer.shadowColor = UIColor.black.cgColor
        cardBackground.layer.shadowOpacity = 0.22
        cardBackground.layer.shadowRadius = 12
        cardBackground.layer.shadowOffset = CGSize(width: 0, height: 6)

        cardBackground.layer.shouldRasterize = true
        cardBackground.layer.rasterizationScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
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
        currentImageURL = nil
        distanceWorkItem?.cancel()
        distanceWorkItem = nil

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
        borrowerItemDistance?.text = ""
        borrowerItemOwnerName?.text = "By —"

        // Async distance from item lat/lon or owner address
        distanceWorkItem?.cancel()
        distanceWorkItem = Task { [weak self] in
            let text = await DistanceService.shared.distanceText(for: item)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.borrowerItemDistance?.text = text }
        }

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
        borrowerItemDistance?.text = ""
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
        borrowerItemName?.text = request.items?.title ?? request.item_id

        if let p = request.items?.price_per_day {
            let amount = NSNumber(value: p)
            borrowerItemRate?.text = (currencyFormatter.string(from: amount) ?? "\(p)") + " / day"
        } else {
            let sql = DateFormatter()
            sql.calendar = Calendar(identifier: .gregorian)
            sql.timeZone = .current
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

        borrowerItemOwnerName?.text = "Status: \(request.status.capitalized)"

        // Distance from owner's address
        borrowerItemDistance?.text = ""
        distanceWorkItem?.cancel()
        distanceWorkItem = Task { [weak self] in
            let text = await DistanceService.shared.distanceText(toUserId: request.owner_id)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.borrowerItemDistance?.text = text }
        }

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
        currentImageURL = url

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
            guard self.currentImageURL == url else { return }
            BorrowerImageCache.shared.setImage(image, forKey: url.absoluteString)
            DispatchQueue.main.async {
                guard self.currentImageURL == url else { return }
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
