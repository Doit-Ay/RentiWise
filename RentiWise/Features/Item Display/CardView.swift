import UIKit

final class CardView: UIView {

    // MARK: - Colors / metrics
    private let teal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let outerCornerRadius: CGFloat = 20
    private let innerCornerRadius: CGFloat = 16
    private let outerBorderWidthOtherSides: CGFloat = 2
    private let outerBorderWidthLeft: CGFloat = 5

    // Insets (outer spacing around card) — THIS is what CardsViewController sets
    var contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16) {
        didSet {
            // Update constraints to reflect new insets
            cardTopConstraint?.constant = contentInsets.top
            cardLeadingConstraint?.constant = contentInsets.leading
            cardTrailingConstraint?.constant = -contentInsets.trailing
            cardBottomConstraint?.constant = -contentInsets.bottom
            setNeedsLayout()
        }
    }

    // MARK: - Layers for outer border
    private let outerBorderLayer = CAShapeLayer()
    private let outerLeftEdgeLayer = CAShapeLayer()

    // MARK: - Subviews (inner content)
    private let cardContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        v.layer.masksToBounds = true
        return v
    }()

    // Keep the rest of your subviews exactly as you have them...
    let itemImageView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = UIColor(white: 0.95, alpha: 1)
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let rateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let ratingLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let distanceIcon: UIImageView = {
        let img = UIImageView(image: UIImage(systemName: "location.fill"))
        img.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        return img
    }()

    private let distanceLabel: UILabel = {
        let l = UILabel()
        l.text = "Distance"
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let heartButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "heart"), for: .normal)
        b.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .clear
        b.layer.cornerRadius = 20
        b.layer.borderWidth = 2
        b.layer.borderColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0).cgColor
        return b
    }()

    // Constraints we adjust when contentInsets changes
    private var cardTopConstraint: NSLayoutConstraint?
    private var cardLeadingConstraint: NSLayoutConstraint?
    private var cardTrailingConstraint: NSLayoutConstraint?
    private var cardBottomConstraint: NSLayoutConstraint?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        translatesAutoresizingMaskIntoConstraints = false
        setupOuterBorderLayers()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        translatesAutoresizingMaskIntoConstraints = false
        setupOuterBorderLayers()
        setupLayout()
    }

    // MARK: - Outer border layers
    private func setupOuterBorderLayers() {
        outerBorderLayer.fillColor = UIColor.clear.cgColor
        outerBorderLayer.strokeColor = teal.cgColor
        outerBorderLayer.lineWidth = outerBorderWidthOtherSides
        outerBorderLayer.lineJoin = .round
        outerBorderLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(outerBorderLayer)

        outerLeftEdgeLayer.fillColor = UIColor.clear.cgColor
        outerLeftEdgeLayer.strokeColor = teal.cgColor
        outerLeftEdgeLayer.lineWidth = outerBorderWidthLeft
        outerLeftEdgeLayer.lineJoin = .round
        outerLeftEdgeLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(outerLeftEdgeLayer)
    }

    // MARK: - Layout inner content
    private func setupLayout() {
        addSubview(cardContainer)

        cardTopConstraint = cardContainer.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top)
        cardLeadingConstraint = cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.leading)
        cardTrailingConstraint = cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.trailing)
        cardBottomConstraint = cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)

        NSLayoutConstraint.activate([
            cardTopConstraint!, cardLeadingConstraint!, cardTrailingConstraint!, cardBottomConstraint!
        ])

        cardContainer.layer.cornerRadius = innerCornerRadius

        // Add inner subviews and constraints (use your existing ones)
        cardContainer.addSubview(itemImageView)
        cardContainer.addSubview(titleLabel)
        cardContainer.addSubview(rateLabel)
        cardContainer.addSubview(ratingLabel)
        cardContainer.addSubview(distanceIcon)
        cardContainer.addSubview(distanceLabel)
        cardContainer.addSubview(heartButton)

        NSLayoutConstraint.activate([
            itemImageView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            itemImageView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            itemImageView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -48),
            itemImageView.widthAnchor.constraint(equalTo: itemImageView.heightAnchor),

            heartButton.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            heartButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 10),
            heartButton.widthAnchor.constraint(equalToConstant: 40),
            heartButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: heartButton.leadingAnchor, constant: -10),

            rateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            rateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabel.trailingAnchor.constraint(lessThanOrEqualTo: heartButton.leadingAnchor, constant: -10),

            ratingLabel.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: 4),
            ratingLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            ratingLabel.trailingAnchor.constraint(lessThanOrEqualTo: heartButton.leadingAnchor, constant: -10),

            distanceIcon.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            distanceIcon.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -12),
            distanceIcon.widthAnchor.constraint(equalToConstant: 18),
            distanceIcon.heightAnchor.constraint(equalToConstant: 18),

            distanceLabel.centerYAnchor.constraint(equalTo: distanceIcon.centerYAnchor),
            distanceLabel.leadingAnchor.constraint(equalTo: distanceIcon.trailingAnchor, constant: 8),
            distanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardContainer.trailingAnchor, constant: -16),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOuterBorderPaths()
    }

    private func updateOuterBorderPaths() {
        let rect = bounds
        let rounded = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: outerCornerRadius)
        outerBorderLayer.frame = bounds
        outerBorderLayer.path = rounded.cgPath

        let leftInset: CGFloat = 1
        let topY = outerCornerRadius + leftInset
        let bottomY = rect.height - outerCornerRadius - leftInset
        let x = leftInset

        let leftEdge = UIBezierPath()
        leftEdge.move(to: CGPoint(x: x, y: topY))
        leftEdge.addLine(to: CGPoint(x: x, y: bottomY))

        outerLeftEdgeLayer.frame = bounds
        outerLeftEdgeLayer.path = leftEdge.cgPath
    }

    // MARK: - Public API
    func configure(title: String, priceText: String, ratingText: String, distanceText: String? = nil) {
        titleLabel.text = title
        rateLabel.text = priceText
        ratingLabel.text = ratingText
        if let distanceText { distanceLabel.text = distanceText }
    }

    func setImage(_ image: UIImage?) {
        itemImageView.image = image
    }

    func setImage(from url: URL) {
        UIImageView.loadImage(from: url) { [weak self] image in
            self?.itemImageView.image = image
        }
    }
}
