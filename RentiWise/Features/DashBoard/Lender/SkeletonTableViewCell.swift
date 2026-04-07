// SkeletonTableViewCell.swift
// RentiWise
//
// A shimmer-animated placeholder cell that mirrors the Listing/History card layout.
// Used while data is being fetched so the screen never shows a jarring empty state.

import UIKit

// MARK: - Shimmer gradient layer

private final class ShimmerLayer: CAGradientLayer {

    private static let shimmerLight = UIColor(white: 1.0, alpha: 0.65).cgColor
    private static let shimmerBase  = UIColor(white: 0.92, alpha: 1.00).cgColor

    override init() {
        super.init()
        configureBaseAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBaseAppearance()
    }

    private func configureBaseAppearance() {
        startPoint  = CGPoint(x: 0, y: 0.5)
        endPoint    = CGPoint(x: 1, y: 0.5)
        locations   = [-1.0, -0.5, 0.0]
        colors      = [ShimmerLayer.shimmerBase, ShimmerLayer.shimmerLight, ShimmerLayer.shimmerBase]
        speed       = 0   // driven manually
    }

    func startShimmering() {
        let animation        = CABasicAnimation(keyPath: "locations")
        animation.fromValue  = [-1.0, -0.5, 0.0]
        animation.toValue    = [1.0,  1.5,  2.0]
        animation.duration   = 1.4
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        speed = 1
        add(animation, forKey: "shimmer")
    }

    func stopShimmering() {
        removeAnimation(forKey: "shimmer")
    }
}

// MARK: - Skeleton block view (a rounded grey rectangle with shimmer)

private final class SkeletonBlock: UIView {
    private let shimmer = ShimmerLayer()

    init(cornerRadius: CGFloat = 8) {
        super.init(frame: .zero)
        configureBaseAppearance(cornerRadius: cornerRadius)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBaseAppearance(cornerRadius: 8)
    }

    private func configureBaseAppearance(cornerRadius: CGFloat) {
        backgroundColor = UIColor.secondarySystemFill
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmer.frame = bounds
        if shimmer.superlayer == nil { layer.addSublayer(shimmer) }
    }

    func startShimmering() { shimmer.startShimmering() }
    func stopShimmering()  { shimmer.stopShimmering()  }
}

// MARK: - Skeleton cell

final class SkeletonTableViewCell: UITableViewCell {

    static let reuseID = "SkeletonCell"

    // Placeholder shapes
    private let cardView     = UIView()
    private let imagePlaceholder = SkeletonBlock(cornerRadius: 12)
    private let titleBlock   = SkeletonBlock(cornerRadius: 6)
    private let subtitleBlock = SkeletonBlock(cornerRadius: 6)
    private let tagBlock      = SkeletonBlock(cornerRadius: 6)

    private var allBlocks: [SkeletonBlock] {
        [imagePlaceholder, titleBlock, subtitleBlock, tagBlock]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Card container
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.secondarySystemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.masksToBounds = false
        cardView.layer.shadowColor  = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius  = 10
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 6)
        contentView.addSubview(cardView)

        [imagePlaceholder, titleBlock, subtitleBlock, tagBlock].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }

        let inset: CGFloat = 16
        let imgSize: CGFloat = 84
        let pad: CGFloat = 12

        NSLayoutConstraint.activate([
            // Card
            cardView.leadingAnchor.constraint(equalTo:  contentView.leadingAnchor,  constant: inset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            cardView.topAnchor.constraint(equalTo:      contentView.topAnchor,      constant: 8),
            cardView.bottomAnchor.constraint(equalTo:   contentView.bottomAnchor,   constant: -8),

            // Image placeholder (left square)
            imagePlaceholder.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            imagePlaceholder.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            imagePlaceholder.widthAnchor.constraint(equalToConstant: imgSize),
            imagePlaceholder.heightAnchor.constraint(equalToConstant: imgSize),

            // Title bar
            titleBlock.leadingAnchor.constraint(equalTo: imagePlaceholder.trailingAnchor, constant: pad),
            titleBlock.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad * 2),
            titleBlock.topAnchor.constraint(equalTo: imagePlaceholder.topAnchor, constant: 4),
            titleBlock.heightAnchor.constraint(equalToConstant: 16),

            // Subtitle bar
            subtitleBlock.leadingAnchor.constraint(equalTo: titleBlock.leadingAnchor),
            subtitleBlock.widthAnchor.constraint(equalTo: titleBlock.widthAnchor, multiplier: 0.6),
            subtitleBlock.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 10),
            subtitleBlock.heightAnchor.constraint(equalToConstant: 13),

            // Tag bar
            tagBlock.leadingAnchor.constraint(equalTo: titleBlock.leadingAnchor),
            tagBlock.widthAnchor.constraint(equalTo: titleBlock.widthAnchor, multiplier: 0.4),
            tagBlock.topAnchor.constraint(equalTo: subtitleBlock.bottomAnchor, constant: 10),
            tagBlock.heightAnchor.constraint(equalToConstant: 13),
        ])
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { allBlocks.forEach { $0.startShimmering() } }
        else             { allBlocks.forEach { $0.stopShimmering()  } }
    }
}
