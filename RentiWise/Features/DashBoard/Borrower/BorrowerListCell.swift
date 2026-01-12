// BorrowerListCell.swift
import UIKit

final class BorrowerListCell: UITableViewCell {
    static let reuseID = "BorrowerListCell"

    private let cardView = UIView()
    private let thumbImageView = UIImageView()
    private let titleLabel = UILabel()
    private let rateLabel = UILabel()
    private let ownerStatusLabel = UILabel()

    private var imageTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        buildUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        thumbImageView.image = nil
        titleLabel.text = nil
        rateLabel.text = nil
        ownerStatusLabel.text = nil
    }

    private func buildUI() {
        // Card
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.masksToBounds = false
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.10
        cardView.layer.shadowRadius = 6
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.addSubview(cardView)

        // Image
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 12

        // Labels
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.font = .systemFont(ofSize: 14, weight: .regular)
        rateLabel.textColor = .secondaryLabel
        rateLabel.numberOfLines = 1

        ownerStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        ownerStatusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        ownerStatusLabel.textColor = .tertiaryLabel
        ownerStatusLabel.numberOfLines = 1

        cardView.addSubview(thumbImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(rateLabel)
        cardView.addSubview(ownerStatusLabel)

        let inset: CGFloat = 16
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -inset),

            thumbImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            thumbImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 96),
            thumbImageView.heightAnchor.constraint(equalToConstant: 96),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            rateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            rateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            ownerStatusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            ownerStatusLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            ownerStatusLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    func configure(title: String, pricePerDay: Double?, status: String, currencyFormatter: NumberFormatter, imageURL: URL?) {
        titleLabel.text = title

        if let p = pricePerDay {
            let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
            rateLabel.text = text
        } else {
            rateLabel.text = ""
        }

        ownerStatusLabel.text = "Owner • \(status.capitalized)"

        if let url = imageURL {
            loadImage(url: url)
        } else {
            thumbImageView.image = UIImage(systemName: "photo")
            thumbImageView.contentMode = .scaleAspectFit
            thumbImageView.tintColor = .secondaryLabel
        }
    }

    private func loadImage(url: URL) {
        if let cached = BorrowerListImageCache.shared.image(forKey: url.absoluteString) {
            thumbImageView.image = cached
            thumbImageView.contentMode = .scaleAspectFill
            return
        }

        imageTask?.cancel()
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        imageTask = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let img = UIImage(data: data) else { return }
            BorrowerListImageCache.shared.setImage(img, forKey: url.absoluteString)
            DispatchQueue.main.async {
                self.thumbImageView.image = img
                self.thumbImageView.contentMode = .scaleAspectFill
            }
        }
        imageTask?.resume()
    }
}

private final class BorrowerListImageCache {
    static let shared = BorrowerListImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func setImage(_ img: UIImage, forKey key: String) { cache.setObject(img, forKey: key as NSString) }
}
