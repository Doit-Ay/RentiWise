//
//  HomeViewController+FeaturedItems.swift
//  RentiWise
//
//  Extracted from HomeViewController.swift — Featured items loading, display, and owner name resolution.
//

import UIKit
import Supabase

// MARK: - Featured items loading
extension HomeViewController {

    func loadFeaturedItems(forceRefresh: Bool = false) async {
        // On cold start, wait for PreloadManager so we have data ready
        if !forceRefresh, !PreloadManager.shared.isComplete {
            await PreloadManager.shared.waitForCompletion(timeout: 4.0)
        }

        let me = await SupabaseManager.shared.currentUserId()

        // LOGGED OUT: Skip fetching — show placeholder instead
        if me == nil {
            await MainActor.run {
                self.applyFeatured(items: [], currentUserId: nil)
                self.trendingItems = []
                self.trendingCollectionView?.reloadData()
                self.updateTrendingEmptyState()
                self.showNoNearbyItemsBanner(false)
                self.recalculateScrollContentHeight()
            }
            return
        }

        // On cold start, use PreloadManager's cached data to avoid duplicate API call.
        let allItems: [Item]
        if !forceRefresh, PreloadManager.shared.isComplete, !PreloadManager.shared.allFetchedItems.isEmpty {
            allItems = PreloadManager.shared.allFetchedItems
        } else if !forceRefresh, PreloadManager.shared.isComplete, PreloadManager.shared.allFetchedItems.isEmpty {
            // Preload completed but found no items — don't re-fetch
            allItems = []
        } else {
            // Network fetch (subsequent refreshes or cache miss)
            do {
                allItems = try await itemsService.fetchItems(category: "")
            } catch {
                await MainActor.run {
                    self.applyFeatured(items: [], currentUserId: me)
                }
                return
            }
        }

        // Filter items within 30km radius and sort by distance (nearest first)
        let nearbyItems = await DistanceService.shared.filterItemsWithinRadius(allItems)

        let featured = Array(nearbyItems.prefix(4))

        await MainActor.run {
            self.applyFeatured(items: featured, currentUserId: me)
            self.updateTrendingItems(from: nearbyItems)

            // Show or hide the "Be the first to list" banner
            if nearbyItems.isEmpty {
                self.showNoNearbyItemsBanner(true)
            } else {
                self.showNoNearbyItemsBanner(false)
            }

            // Recalculate the scroll content height to avoid excess whitespace
            self.recalculateScrollContentHeight()
        }
    }

    /// Dynamically adjusts the homeBG (scroll content) height constraint
    /// so it wraps tightly around visible content instead of a fixed 1600pt.
    /// Also repositions the "You ❤️ Rentiwise" tagline to sit right below the last content.
    @MainActor
    func recalculateScrollContentHeight() {
        guard let scrollContent = homeBG else { return }

        // Force layout so subview frames are up-to-date
        scrollContent.layoutIfNeeded()

        // Find the bottom-most visible subview, excluding the bottom tagline
        var maxBottom: CGFloat = 0
        for subview in scrollContent.subviews where !subview.isHidden && subview.alpha > 0 {
            // Skip the "You ❤️ Rentiwise" tagline — we'll reposition it afterwards
            if subview === Homepagelastline { continue }
            let bottom = subview.frame.maxY
            if bottom > maxBottom {
                maxBottom = bottom
            }
        }

        // Reposition the tagline label right below the last content item
        if let tagline = Homepagelastline {
            let taglinePadding: CGFloat = 20
            tagline.frame = CGRect(
                x: tagline.frame.origin.x,
                y: maxBottom + taglinePadding,
                width: tagline.frame.width,
                height: tagline.frame.height
            )
            // Update maxBottom to include the repositioned tagline
            maxBottom = tagline.frame.maxY
        }

        // Add padding at the bottom
        let targetHeight = max(maxBottom + 40, 600)

        for c in scrollContent.constraints where c.firstAttribute == .height && c.firstItem === scrollContent {
            c.constant = targetHeight
        }
        scrollContent.superview?.setNeedsLayout()
    }

    /// Shows/hides a polished empty-state CTA when no items are nearby.
    @MainActor
    func showNoNearbyItemsBanner(_ show: Bool) {
        let bannerTag = 9876
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

        if !show {
            view.viewWithTag(bannerTag)?.removeFromSuperview()
            return
        }

        // Don't add duplicate
        if view.viewWithTag(bannerTag) != nil { return }

        let banner = UIView()
        banner.tag = bannerTag
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.backgroundColor = .white
        banner.layer.cornerRadius = 20
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = 0.08
        banner.layer.shadowRadius = 16
        banner.layer.shadowOffset = CGSize(width: 0, height: 4)

        // Large centered icon
        let icon = UIImageView(image: UIImage(systemName: "shippingbox.and.arrow.backward"))
        icon.tintColor = brandTeal
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Be the first to list!"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "No items are available in your area yet.\nList your items and start earning from people nearby."
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle("  List Your First Item", for: .normal)
        ctaButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        ctaButton.tintColor = .white
        ctaButton.backgroundColor = brandTeal
        ctaButton.layer.cornerRadius = 14
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.addTarget(self, action: #selector(additemHomeTapped(_:)), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel, ctaButton])
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(contentStack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 56),
            icon.heightAnchor.constraint(equalToConstant: 56),
            ctaButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -32),
            ctaButton.heightAnchor.constraint(equalToConstant: 50),
            contentStack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -28),
        ])

        // Place the banner inside the scroll content view, below the listing section
        if let scrollContent = trendingUiView?.superview {
            scrollContent.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 20),
                banner.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -20),
                banner.topAnchor.constraint(equalTo: (trendingUiView ?? listingUIView ?? scrollContent).bottomAnchor, constant: 24),
            ])
        } else {
            view.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                banner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                banner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
            ])
        }

        // Subtle entrance animation
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: 10)
        UIView.animate(withDuration: 0.35, delay: 0.1, options: .curveEaseOut) {
            banner.alpha = 1
            banner.transform = .identity
        }
    }

    /// Tag for the "sign up" placeholder under New Arrivals
    private static let newArrivalsPlaceholderTag = 8899

    func applyFeatured(items: [Item], currentUserId: String?) {
        // Find and hide/show the "New Arrivals" label and featured card stack
        let newArrivalsLabel = item1CardView?.superview?.superview?.subviews
            .compactMap({ $0 as? UILabel })
            .first(where: { $0.text == "New Arrivals" })
        let cardStack = item1CardView?.superview as? UIStackView
        let scrollContent = item1CardView?.superview?.superview

        // Remove any existing placeholder
        scrollContent?.viewWithTag(Self.newArrivalsPlaceholderTag)?.removeFromSuperview()

        // LOGGED OUT: hide items, show sign-up placeholder
        let isLoggedOut = (currentUserId == nil)
        if isLoggedOut {
            newArrivalsLabel?.isHidden = false
            cardStack?.isHidden = true

            // Add placeholder text below the "New Arrivals" label
            if let scrollContent, let arrivalsLabel = newArrivalsLabel {
                let placeholder = UILabel()
                placeholder.tag = Self.newArrivalsPlaceholderTag
                placeholder.text = "No items in New Arrivals.\nSign up to explore rentals near you!"
                placeholder.font = .systemFont(ofSize: 15, weight: .medium)
                placeholder.textColor = .secondaryLabel
                placeholder.textAlignment = .center
                placeholder.numberOfLines = 0
                placeholder.translatesAutoresizingMaskIntoConstraints = false

                scrollContent.addSubview(placeholder)
                NSLayoutConstraint.activate([
                    placeholder.topAnchor.constraint(equalTo: arrivalsLabel.bottomAnchor, constant: 16),
                    placeholder.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 20),
                    placeholder.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -20),
                ])
            }

            // Clear all slots
            let slots: [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?)] = [
                (item1Image, item1Name, item1Rate, item1Rating, item1Distance, item1owner, item1CardView, rentButton1),
                (item2Image, item2Name, item2Rate, item2Rating, item2Distance, item2owner, item2CardView, rentButton2),
                (item3Image, item3Name, item3Rate, item3Rating, item3Distance, item3owner, item3CardView, rentButton3),
                (item4Image, item4Name, item4Rate, item4Rating, item4Distance, item4owner, item4CardView, rentButton4)
            ]
            for slot in slots { clearFeaturedSlot(slot) }
            self.featuredItems = []
            return
        }

        // LOGGED IN: normal behavior
        if items.isEmpty {
            newArrivalsLabel?.isHidden = true
            cardStack?.isHidden = true
        } else {
            newArrivalsLabel?.isHidden = false
            cardStack?.isHidden = false
        }

        let slots: [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?)] = [
            (item1Image, item1Name, item1Rate, item1Rating, item1Distance, item1owner, item1CardView, rentButton1),
            (item2Image, item2Name, item2Rate, item2Rating, item2Distance, item2owner, item2CardView, rentButton2),
            (item3Image, item3Name, item3Rate, item3Rating, item3Distance, item3owner, item3CardView, rentButton3),
            (item4Image, item4Name, item4Rate, item4Rating, item4Distance, item4owner, item4CardView, rentButton4)
        ]

        for (i, slot) in slots.enumerated() {
            if i < items.count {
                configureFeaturedSlot(slot, with: items[i], currentUserId: currentUserId)

                // Wire Rent button to open RequestViewController for the corresponding featured item slot
                if let btn = slot.7 {
                    btn.removeTarget(nil, action: nil, for: .allEvents)
                    switch i {
                    case 0:
                        btn.addTarget(self, action: #selector(rentButton1Tapped(_:)), for: .touchUpInside)
                    case 1:
                        btn.addTarget(self, action: #selector(rentButton2Tapped(_:)), for: .touchUpInside)
                    case 2:
                        btn.addTarget(self, action: #selector(rentButton3Tapped(_:)), for: .touchUpInside)
                    case 3:
                        btn.addTarget(self, action: #selector(rentButton4Tapped(_:)), for: .touchUpInside)
                    default:
                        break
                    }
                }
            } else {
                clearFeaturedSlot(slot)
            }
        }
        self.featuredItems = items
        
        // Batch resolve all owner names in a single query instead of 4 individual ones
        resolveOwnerNamesBatch(for: items)
    }

    func configureFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?), with item: Item, currentUserId: String?) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel, ownerLabel, cardView, rentButton) = slot

        cardView?.isHidden = false
        
        let isOwn = (currentUserId?.lowercased() == item.owner_id.lowercased())
        rentButton?.isEnabled = !isOwn
        rentButton?.alpha = isOwn ? 0.4 : 1.0
        
        ownerLabel?.text = nil

        nameLabel?.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        rateLabel?.text = "\(currencyFormatter.string(from: amount) ?? "₹\(item.price_per_day)") / day"

        // Show rating + review count
        if let avg = item.average_rating, let cnt = item.review_count, cnt > 0 {
            let valueText = String(format: "%.1f", avg)
            let reviewsText = "(\(cnt))"
            ratingLabel?.attributedText = makeYellowStarRatingText(valueText: valueText, reviewsText: reviewsText)
        } else {
            ratingLabel?.attributedText = makeYellowStarRatingText(valueText: "New", reviewsText: nil)
        }

        // Distance (async)
        distanceLabel?.text = "..."
        Task { [weak distanceLabel] in
            let text = await DistanceService.shared.distanceText(for: item)
            await MainActor.run { distanceLabel?.text = text }
        }

        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            setImage(into: imageView, from: url)
        } else {
            imageView?.image = UIImage(systemName: "photo")
            imageView?.tintColor = .secondaryLabel
            imageView?.contentMode = .scaleAspectFill
            imageView?.clipsToBounds = true
        }
    }

    func clearFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?)) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel, ownerLabel, cardView, rentButton) = slot
        cardView?.isHidden = true
        rentButton?.isEnabled = false
        imageView?.image = nil
        nameLabel?.text = nil
        rateLabel?.text = nil
        ratingLabel?.text = nil
        distanceLabel?.text = nil
        ownerLabel?.text = nil
    }

    func setImage(into imageView: UIImageView?, from url: URL) {
        guard let imageView = imageView else { return }
        if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
            imageView.image = cached
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let d = data, let img = UIImage(data: d) else { return }
            FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
            DispatchQueue.main.async {
                imageView.image = img
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
            }
        }.resume()
    }

    // MARK: - Owner name resolution for featured items

    func capitalizingFirstLetter(_ s: String) -> String {
        guard let first = s.unicodeScalars.first else { return s }
        return String(first).uppercased() + String(s.unicodeScalars.dropFirst())
    }

    func resolveOwnerNamesBatch(for items: [Item]) {
        guard !items.isEmpty else { return }
        
        // Collect unique owner IDs that need resolution
        let ownerIds = Array(Set(items.map { $0.owner_id }))
        
        // Check cache first — if all are cached, apply immediately without a network call
        let allCached = ownerIds.allSatisfy { ownerNameCache[$0] != nil }
        if allCached {
            for (i, item) in items.enumerated() {
                let name = ownerNameCache[item.owner_id] ?? "Owner"
                applyOwnerName(name, toSlotAt: i)
            }
            return
        }
        
        Task {
            // Single batch query for all owner names
            struct NameDTO: Decodable {
                let id: String
                let full_name: String?
            }
            
            do {
                let response = try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .select("id,full_name")
                    .in("id", values: ownerIds)
                    .execute()
                
                let profiles = try JSONDecoder().decode([NameDTO].self, from: response.data)
                var nameMap: [String: String] = [:]
                for profile in profiles {
                    if let name = profile.full_name, !name.isEmpty {
                        nameMap[profile.id] = capitalizingFirstLetter(name)
                    }
                }
                
                await MainActor.run {
                    for (i, item) in items.enumerated() {
                        let name = nameMap[item.owner_id] ?? "Owner"
                        self.ownerNameCache[item.owner_id] = name
                        self.applyOwnerName(name, toSlotAt: i)
                    }
                }
            } catch {
                await MainActor.run {
                    for (i, _) in items.enumerated() {
                        self.applyOwnerName("Owner", toSlotAt: i)
                    }
                }
            }
        }
    }

    func resolveOwnerName(for ownerId: String, slotIndex: Int) {
        Task {
            if let name = try? await fetchName(from: "user_profiles", ownerId: ownerId), !name.isEmpty {
                await applyOwnerName(capitalizingFirstLetter(name), toSlotAt: slotIndex)
                return
            }

            // Final fallback: "Owner"
            await applyOwnerName("Owner", toSlotAt: slotIndex)
        }
    }

    func fetchName(from table: String, ownerId: String) async throws -> String? {
        struct NameDTO: Decodable { let full_name: String? }
        let response = try await SupabaseManager.shared.client
            .from(table)
            .select("full_name")
            .eq("id", value: ownerId)
            .single()
            .execute()
        return try JSONDecoder().decode(NameDTO.self, from: response.data).full_name
    }

    @MainActor
    func applyOwnerName(_ name: String, toSlotAt slotIndex: Int) {
        let display = name
        switch slotIndex {
        case 0: item1owner?.text = display
        case 1: item2owner?.text = display
        case 2: item3owner?.text = display
        case 3: item4owner?.text = display
        default: break
        }
    }

    // MARK: - Rating attributed text helper (yellow star)
    func makeYellowStarRatingText(valueText: String, reviewsText: String? = "(23)") -> NSAttributedString {
        let star = "★"
        let space = " "
        let full = reviewsText.map { "\(star)\(space)\(valueText) \($0)" } ?? "\(star)\(space)\(valueText)"
        let attr = NSMutableAttributedString(string: full, attributes: [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ])

        if let starRange = full.range(of: star) {
            let ns = NSRange(starRange, in: full)
            attr.addAttribute(.foregroundColor, value: UIColor.systemYellow, range: ns)
        }
        return attr
    }
}
