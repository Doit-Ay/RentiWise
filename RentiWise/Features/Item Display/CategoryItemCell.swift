// CategoryItemCell.swift
// RentiWise

import UIKit
import Supabase

protocol CategoryItemCellDelegate: AnyObject {
    func categoryItemCellDidTapRent(_ cell: CategoryItemCell)
}

final class CategoryItemCell: UITableViewCell {

    @IBOutlet weak var itemimage: UIImageView!
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var itemRate: UILabel!
    @IBOutlet weak var itemDistance: UILabel!
    @IBOutlet weak var itemRating: UILabel!
    @IBOutlet weak var itemViewCard: UIView?
    @IBOutlet weak var rentbutton: UIButton!
    
    @IBOutlet weak var ownerName: UILabel!

    weak var delegate: CategoryItemCellDelegate?

    @IBAction func rentButtonTapped(_ sender: UIButton) {
        debugLog("🔘 CategoryItemCell: Rent button tapped!")
        debugLog("🔘 Delegate is: \(delegate != nil ? "SET" : "NIL")")
        delegate?.categoryItemCellDidTapRent(self)
    }
    
    // Controls the spacing around the card; use 8 top/bottom so two cells make 16 between cards
    private let verticalInset: CGFloat = 8
    private let horizontalInset: CGFloat = 20

    private var addedInsetConstraints = false

    // Card appearance
    private let cornerRadius: CGFloat = 20

    // Track the owner id this cell is currently representing to guard against reuse
    private var currentOwnerId: String?

    // Track the item id this cell is showing (to further guard async distance updates)
    private var currentItemId: String?

    // Simple UI cache to avoid flicker while scrolling; key by owner_id (owner-level distance)
    private static let distanceCache = NSCache<NSString, NSString>()

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Make sure shadows aren’t clipped by the cell or contentView
        clipsToBounds = false
        contentView.clipsToBounds = false

        // Card styling: glass effect to match Home cards
        if let card = itemViewCard {
            // Ensure no solid background; glass effect will handle visuals
            card.backgroundColor = .clear
            card.layer.cornerRadius = cornerRadius
            card.layer.masksToBounds = false
            // Apply glass with default settings
            card.applyGlassEffect(
                cornerRadius: cornerRadius,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: .white,
                tintAlpha: 0.14,
                showsHighlight: true,
                highlightAlpha: 0.15
            )
            // Soften the shadow a bit (lighter and closer)
            card.layer.shadowOpacity = 0.12
            card.layer.shadowRadius = 8
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
        }

        // Image styling
        itemimage?.layer.cornerRadius = 12
        itemimage?.clipsToBounds = true
        itemimage?.contentMode = .scaleAspectFill

        // Rent button: simple solid background with shadow (no glass effect to avoid blocking touches)
        if let b = rentbutton {
            // CRITICAL: Ensure button can receive touches
            b.isUserInteractionEnabled = true
            
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.setTitleColor(UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0), for: .normal) // Teal text
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            
            // Soft off-white background (less bright than pure white)
            b.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
            b.layer.cornerRadius = 12
            b.clipsToBounds = false
            
            // Subtle shadow to make it stand out
            b.layer.shadowColor = UIColor.black.cgColor
            b.layer.shadowOpacity = 0.15
            b.layer.shadowRadius = 6
            b.layer.shadowOffset = CGSize(width: 0, height: 3)
            
            // Ensure button is on top
            contentView.bringSubviewToFront(b)
        }

        // Add insets around the card by constraining it inside contentView
        applyCardInsetsIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure constraints are in place if the NIB/storyboard was missing them
        applyCardInsetsIfNeeded()
    }

    private func applyCardInsetsIfNeeded() {
        guard let card = itemViewCard, !addedInsetConstraints else { return }
        card.translatesAutoresizingMaskIntoConstraints = false

        // Remove any conflicting constraints that pin the card edge-to-edge
        let toRemove = contentView.constraints.filter { constraint in
            let involvesCard = (constraint.firstItem as? UIView) === card || (constraint.secondItem as? UIView) === card
            return involvesCard
        }
        contentView.removeConstraints(toRemove)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalInset),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalInset),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalInset),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalInset),
        ])

        addedInsetConstraints = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        itemimage?.image = nil
        itemName?.text = nil
        itemRate?.text = nil
        itemDistance?.text = nil
        itemRating?.attributedText = nil
        itemRating?.text = nil
        ownerName?.text = nil
        currentOwnerId = nil
        currentItemId = nil
    }

    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        itemName?.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        let currency = currencyFormatter.string(from: amount) ?? "\(item.price_per_day)"
        itemRate?.text = "\(currency) / day"

        // Rating: show real stats if present, else “New”
        if let avg = item.average_rating, let count = item.review_count, count > 0 {
            let value = String(format: "%.1f", avg)
            // Show only star + number (no “review(s)”)
            applyYellowStarRating(valueText: value)
        } else {
            itemRating?.attributedText = nil
            itemRating?.text = "New"
            itemRating?.textColor = .secondaryLabel
        }

        // Distance placeholder while loading
        itemDistance?.text = "…"

        // Owner name: set placeholder, then resolve asynchronously with cache
        ownerName?.text = "Owner"
        currentOwnerId = item.owner_id
        currentItemId = item.id
        resolveOwnerName(for: item.owner_id)

        // Distance: owner-level, matching Home/Product behavior
        resolveDistance(for: item)

        // If your bucket is private and you need signed URLs:
        if let path = item.images.first {
            itemimage?.image = nil
            Task { [weak self] in
                do {
                    // IMPORTANT: Use your actual bucket name (e.g., "itemimages" per your SQL)
                    let url = try await StorageService().signedURL(bucket: "itemimages", path: path, expiresIn: 3600)
                    UIImageView.loadImage(from: url) { image in
                        self?.itemimage?.image = image
                    }
                } catch {
                    self?.itemimage?.image = nil
                }
            }
        } else {
            itemimage?.image = nil
        }

        // If your bucket is public instead, comment the block above and use:
        /*
        if let path = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            itemimage?.image = nil
            UIImageView.loadImage(from: url) { [weak self] image in
                self?.itemimage?.image = image
            }
        } else {
            itemimage?.image = nil
        }
        */
    }

    // MARK: - Distance resolution (owner-level, cached, reuse-safe, with progressive loading)
    private func resolveDistance(for item: Item) {
        let ownerKey = item.owner_id as NSString

        // 1) UI cache hit to avoid flicker while scrolling
        if let cached = CategoryItemCell.distanceCache.object(forKey: ownerKey) {
            if self.currentOwnerId == item.owner_id, self.currentItemId == item.id {
                self.itemDistance?.text = cached as String
            }
            return
        }

        // 2) Async compute with progressive loading
        Task { [weak self] in
            guard let self else { return }
            
            // Progressive loading: get initial distance (fast), then update with road distance
            let text = await DistanceService.shared.distanceText(for: item) { [weak self] updatedText in
                guard let self = self else { return }
                // Update with accurate road distance when available
                if self.currentOwnerId == item.owner_id, self.currentItemId == item.id {
                    self.itemDistance?.text = updatedText
                    CategoryItemCell.distanceCache.setObject(updatedText as NSString, forKey: ownerKey)
                }
            }
            
            // Cache initial distance for subsequent rows
            CategoryItemCell.distanceCache.setObject(text as NSString, forKey: ownerKey)

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // Reuse guard: ensure this cell still represents the same item/owner
                if self.currentOwnerId == item.owner_id, self.currentItemId == item.id {
                    self.itemDistance?.text = text
                }
            }
        }
    }

    // MARK: - Owner name resolution (self-contained, cached)
    private static var ownerNameCache = NSCache<NSString, NSString>()

    private func resolveOwnerName(for ownerId: String) {
        // 1) Cache hit
        if let cached = CategoryItemCell.ownerNameCache.object(forKey: ownerId as NSString) {
            if currentOwnerId == ownerId {
                ownerName?.text = cached as String
            }
            return
        }

        // 2) Fetch from public.users; if missing, fallback to profiles
        Task { [weak self] in
            guard let self else { return }
            struct NameDTO: Decodable { let full_name: String? }

            // Helper to apply name with cache and reuse guard
            func apply(name: String) async {
                CategoryItemCell.ownerNameCache.setObject(name as NSString, forKey: ownerId as NSString)
                await MainActor.run { [weak self] in
                    if self?.currentOwnerId == ownerId {
                        self?.ownerName?.text = name
                    }
                }
            }

            // Fetch from user_profiles
            do {
                let response = try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .select("full_name")
                    .eq("id", value: ownerId)
                    .limit(1)
                    .execute()

                let rows = try JSONDecoder().decode([NameDTO].self, from: response.data)
                if let fullName = rows.first?.full_name, !fullName.isEmpty {
                    await apply(name: fullName)
                    return
                }
            } catch {
                // fall through to final fallback
            }

            // Final fallback
            await MainActor.run { [weak self] in
                if self?.currentOwnerId == ownerId {
                    self?.ownerName?.text = "Owner"
                }
            }
        }
    }

    // MARK: - Rating styling helpers
    private func applyYellowStarRating(valueText: String) {
        // Build "★ 3.5" with yellow star and black number
        let star = "★"
        let space = " "
        let full = star + space + valueText

        let attr = NSMutableAttributedString(string: full, attributes: [
            .foregroundColor: UIColor.label,
            .font: itemRating?.font ?? UIFont.systemFont(ofSize: 14, weight: .regular)
        ])

        // Color only the star in systemYellow
        if let starRange = full.range(of: star) {
            let nsRange = NSRange(starRange, in: full)
            attr.addAttribute(.foregroundColor, value: UIColor.systemYellow, range: nsRange)
        }

        itemRating?.attributedText = attr
    }
}

