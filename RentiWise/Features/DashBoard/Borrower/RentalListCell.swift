// RentalListCell.swift
import UIKit

final class RentalListCell: UITableViewCell {
    static let reuseID = "RentalListCell"

    // Leading image
    private let thumbImageView = UIImageView()

    // Title
    private let titleLabel = UILabel()

    // Date range + status badge row
    private let dateLabel = UILabel()
    private let statusBadge = PaddingLabel()
    private let metaRow = UIStackView()

    // Trailing price
    private let priceLabel = UILabel()

    // Bottom separator to match native look (we’ll align with 16pt inset)
    private let bottomSeparator = UIView()

    // Cache for image task if you later load from URL
    private var imageTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        thumbImageView.image = nil
        titleLabel.text = nil
        dateLabel.text = nil
        statusBadge.text = nil
        priceLabel.text = nil
    }

    private func buildUI() {
        selectionStyle = .default
        accessoryType = .disclosureIndicator

        // Backgrounds to match system list
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground

        // Image
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 8
        thumbImageView.backgroundColor = .secondarySystemBackground

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        // Date label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        dateLabel.numberOfLines = 1

        // Status badge
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        statusBadge.layer.cornerRadius = 10
        statusBadge.layer.masksToBounds = true
        statusBadge.insets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        statusBadge.textAlignment = .center
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)

        // Meta row: date + badge
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.addArrangedSubview(dateLabel)
        metaRow.addArrangedSubview(statusBadge)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metaRow.addArrangedSubview(spacer)

        // Trailing price
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        priceLabel.textColor = .label
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        // Vertical stack for title + meta
        let textStack = UIStackView(arrangedSubviews: [titleLabel, metaRow])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // Bottom separator (thin)
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.backgroundColor = UIColor.separator

        contentView.addSubview(thumbImageView)
        contentView.addSubview(textStack)
        contentView.addSubview(priceLabel)
        contentView.addSubview(bottomSeparator)

        let inset: CGFloat = 16
        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 48),
            thumbImageView.heightAnchor.constraint(equalToConstant: 48),

            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            priceLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -12),

            // Bottom separator aligned to text/thumbnail area (16pt inset)
            bottomSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            bottomSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSeparator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Public API

    func configure(title: String,
                   startDate: Date?,
                   endDate: Date?,
                   status: String,
                   price: Double?,
                   currencyFormatter: NumberFormatter,
                   image: UIImage?) {
        titleLabel.text = title
        setDateRange(startDate: startDate, endDate: endDate)

        setStatus(status)

        if let price = price {
            // Rounded currency (no decimals). Configure your formatter accordingly.
            let rounded = NSNumber(value: round(price))
            currencyFormatter.minimumFractionDigits = 0
            currencyFormatter.maximumFractionDigits = 0
            priceLabel.text = currencyFormatter.string(from: rounded)
        } else {
            priceLabel.text = nil
        }

        if let image = image {
            thumbImageView.image = image
            thumbImageView.contentMode = .scaleAspectFill
        } else {
            thumbImageView.image = UIImage(systemName: "photo")
            thumbImageView.contentMode = .scaleAspectFit
            thumbImageView.tintColor = .secondaryLabel
        }
    }

    func setDateRange(startDate: Date?, endDate: Date?) {
        if let s = startDate, let e = endDate {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.timeZone = .current
            df.dateFormat = "d MMM yyyy"
            dateLabel.text = "\(df.string(from: s)) — \(df.string(from: e))"
        } else {
            dateLabel.text = "—"
        }
    }

    func setStatus(_ status: String) {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "approved", "completed", "accepted":
            statusBadge.text = "Completed"
            statusBadge.textColor = UIColor.systemGray
            statusBadge.backgroundColor = UIColor.systemGray.withAlphaComponent(0.12)
            statusBadge.layer.borderColor = UIColor.systemGray.withAlphaComponent(0.6).cgColor
            statusBadge.layer.borderWidth = 0.5
        case "pending", "upcoming":
            statusBadge.text = "Upcoming"
            statusBadge.textColor = UIColor.systemBlue
            statusBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
            statusBadge.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
            statusBadge.layer.borderWidth = 0.5
        default:
            statusBadge.text = status.capitalized
            statusBadge.textColor = UIColor.label
            statusBadge.backgroundColor = UIColor.secondarySystemBackground
            statusBadge.layer.borderColor = UIColor.tertiaryLabel.withAlphaComponent(0.6).cgColor
            statusBadge.layer.borderWidth = 0.5
        }
    }
}

// A small label subclass to provide internal padding for the badge
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
