//
//  HomeViewController+Trending.swift
//  RentiWise
//
//  Extracted from HomeViewController.swift — Trending collection view setup + TrendingItemCell.
//

import UIKit
import CoreLocation

// MARK: - Trending UI (horizontal scroller inside trendingUiView)
extension HomeViewController {

    func setupTrendingCollection() {
        guard trendingCollectionView == nil, let host = trendingUiView else { return }

        host.clipsToBounds = false
        host.backgroundColor = .systemGroupedBackground

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemGroupedBackground
        cv.showsHorizontalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.clipsToBounds = false
        cv.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        cv.delaysContentTouches = false

        host.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            cv.topAnchor.constraint(equalTo: host.topAnchor),
            cv.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        cv.dataSource = self
        cv.delegate = self
        cv.register(TrendingItemCell.self, forCellWithReuseIdentifier: TrendingItemCell.reuseID)
        trendingCollectionView = cv
    }

    func updateTrendingItems(from items: [Item]) {
        let requestGeneration = UUID()
        trendingSortGeneration = requestGeneration

        let fallbackSorted = items.sorted(by: isPreferredTrendingItem(_:over:))
        trendingItems = Array(fallbackSorted.prefix(6))
        trendingCollectionView?.reloadData()

        Task { [weak self] in
            guard let self else { return }

            let rankedItems = await withTaskGroup(of: (Item, Double).self, returning: [(Item, Double)].self) { group in
                for item in items {
                    group.addTask {
                        let distance = await DistanceService.shared.rankingDistanceMeters(for: item)
                        return (item, distance)
                    }
                }

                var results: [(Item, Double)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            let distanceSorted = rankedItems.sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                return self.isPreferredTrendingItem(lhs.0, over: rhs.0)
            }.map(\.0)

            await MainActor.run {
                guard self.trendingSortGeneration == requestGeneration else { return }
                self.trendingItems = Array(distanceSorted.prefix(6))
                self.trendingCollectionView?.reloadData()
            }
        }
    }

    func resolveTrendingOwnerName(for ownerId: String, completion: @escaping (String) -> Void) {
        if let cached = ownerNameCache[ownerId] {
            completion(cached)
            return
        }

        Task {
            if let name = try? await fetchName(from: "user_profiles", ownerId: ownerId), !name.isEmpty {
                let display = capitalizingFirstLetter(name)
                ownerNameCache[ownerId] = display
                completion(display)
                return
            }
            let display = "Owner"
            ownerNameCache[ownerId] = display
            completion(display)
        }
    }

    private func isPreferredTrendingItem(_ lhs: Item, over rhs: Item) -> Bool {
        let lhsRating = lhs.average_rating ?? 0
        let rhsRating = rhs.average_rating ?? 0
        if lhsRating != rhsRating {
            return lhsRating > rhsRating
        }

        let lhsReviews = lhs.review_count ?? 0
        let rhsReviews = rhs.review_count ?? 0
        if lhsReviews != rhsReviews {
            return lhsReviews > rhsReviews
        }

        if lhs.hasActiveBoost != rhs.hasActiveBoost {
            return lhs.hasActiveBoost && !rhs.hasActiveBoost
        }

        return (lhs.created_at ?? .distantPast) > (rhs.created_at ?? .distantPast)
    }
}

// MARK: - TrendingItemCell (code-only)
final class TrendingItemCell: UICollectionViewCell {

    static let reuseID = "TrendingItemCell"

    // shadowWrapper sits behind the card and holds the drop shadow so that
    // applyGlassEffect's internal clipsToBounds doesn't mask it.
    private let shadowWrapper = UIView()
    private let card = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()

    private let priceStack = UIStackView()
    private let priceMainLabel = UILabel()

    private let ratingStack = UIStackView()
    private let ratingIcon = UIImageView()
    private let ratingLabel = UILabel()

    private let distanceStack = UIStackView()
    private let distanceIcon = UIImageView()
    private let distanceLabel = UILabel()

    let rentButton = UIButton(type: .system)
    var onRentTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false

        // Shadow wrapper — never clips, so shadow is always visible
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
        shadowWrapper.backgroundColor = .clear
        shadowWrapper.layer.shadowColor = UIColor.black.cgColor
        shadowWrapper.layer.shadowOpacity = 0.14
        shadowWrapper.layer.shadowRadius = 12
        shadowWrapper.layer.shadowOffset = CGSize(width: 0, height: 6)
        shadowWrapper.layer.masksToBounds = false

        contentView.addSubview(shadowWrapper)
        NSLayoutConstraint.activate([
            shadowWrapper.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowWrapper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowWrapper.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowWrapper.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Card sits inside shadow wrapper — glass effect clips to rounded bounds
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = false

        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: false,
            borderAlpha: 0.22,
            tintColorOverride: .white,
            tintAlpha: 0.12
        )

        shadowWrapper.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            card.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor)
        ])

        // Image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemBackground

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .label

        // Price stack
        priceStack.axis = .horizontal
        priceStack.alignment = .firstBaseline
        priceStack.spacing = 2
        priceStack.translatesAutoresizingMaskIntoConstraints = false

        priceMainLabel.font = .systemFont(ofSize: 16, weight: .regular)
        priceMainLabel.textColor = .label
        priceStack.addArrangedSubview(priceMainLabel)

        // Rating stack
        ratingStack.axis = .horizontal
        ratingStack.alignment = .center
        ratingStack.spacing = 4
        ratingStack.translatesAutoresizingMaskIntoConstraints = false

        let starConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        ratingIcon.image = UIImage(systemName: "star.fill", withConfiguration: starConfig)
        ratingIcon.tintColor = UIColor.systemYellow
        ratingIcon.setContentHuggingPriority(.required, for: .horizontal)

        ratingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        ratingLabel.textColor = .label

        ratingStack.addArrangedSubview(ratingIcon)
        ratingStack.addArrangedSubview(ratingLabel)

        // Distance stack
        distanceStack.axis = .horizontal
        distanceStack.alignment = .center
        distanceStack.spacing = 6
        distanceStack.translatesAutoresizingMaskIntoConstraints = false

        let locConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        distanceIcon.image = UIImage(systemName: "mappin.and.ellipse", withConfiguration: locConfig)
        distanceIcon.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        distanceIcon.setContentHuggingPriority(.required, for: .horizontal)

        distanceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        distanceLabel.textColor = .secondaryLabel

        distanceStack.addArrangedSubview(distanceIcon)
        distanceStack.addArrangedSubview(distanceLabel)

        // Rent button — matches featured item card rent buttons (white bg, teal text, soft shadow)
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        rentButton.setTitle("Rent", for: .normal)
        rentButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        rentButton.setTitleColor(brandTeal, for: .normal)
        rentButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        rentButton.backgroundColor = .white
        rentButton.layer.cornerRadius = 16
        rentButton.layer.masksToBounds = false
        // Soft shadow (same feel as featured cards)
        rentButton.layer.shadowColor = UIColor.black.cgColor
        rentButton.layer.shadowOpacity = 0.12
        rentButton.layer.shadowRadius = 6
        rentButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        rentButton.translatesAutoresizingMaskIntoConstraints = false
        rentButton.addTarget(self, action: #selector(rentTapped), for: .touchUpInside)


        // Layout
        let row1 = UIStackView(arrangedSubviews: [priceStack, ratingStack])
        row1.axis = .horizontal
        row1.distribution = .equalSpacing
        row1.alignment = .center

        let row2 = UIStackView(arrangedSubviews: [distanceStack, rentButton])
        row2.axis = .horizontal
        row2.distribution = .equalSpacing
        row2.alignment = .center

        let v = UIStackView(arrangedSubviews: [imageView, titleLabel, row1, row2])
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(v)

        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            imageView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }

    @objc func rentTapped() {
        onRentTapped?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Convert the point to the rent button's coordinate space
        let buttonPoint = rentButton.convert(point, from: self)
        if rentButton.bounds.contains(buttonPoint) && !rentButton.isHidden && rentButton.isEnabled {
            return rentButton
        }
        return super.hitTest(point, with: event)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        priceMainLabel.text = nil
        ratingLabel.text = nil
        distanceLabel.text = nil
        onRentTapped = nil
    }

    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        titleLabel.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        priceMainLabel.text = "\(currencyFormatter.string(from: amount) ?? "₹\(item.price_per_day)") / day"

        if let avg = item.average_rating, let cnt = item.review_count, cnt > 0 {
            ratingLabel.text = String(format: "%.1f (%d)", avg, cnt)
        } else {
            ratingLabel.text = "New"
        }

        distanceLabel.text = "..."
        Task { [weak self] in
            let text = await DistanceService.shared.distanceText(for: item) { updatedText in
                Task { @MainActor [weak self] in
                    self?.distanceLabel.text = updatedText
                }
            }
            await MainActor.run { self?.distanceLabel.text = text }
        }

        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
                imageView.image = cached
                imageView.contentMode = .scaleAspectFill
            } else {
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let d = data, let img = UIImage(data: d) else { return }
                    FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
                    DispatchQueue.main.async {
                        self?.imageView.image = img
                        self?.imageView.contentMode = .scaleAspectFill
                    }
                }.resume()
            }
        } else {
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .secondaryLabel
            imageView.contentMode = .scaleAspectFit
        }
    }
}
