//
//  HomeViewController+FeaturedItems.swift
//  RentiWise
//
//  Extracted from HomeViewController.swift — Featured items loading, display, and owner name resolution.
//

import UIKit
import Supabase

// MARK: - Home feed loading
extension HomeViewController {

    func loadFeaturedItems(forceRefresh: Bool = false) async {
        // On cold start, wait for PreloadManager so we have data ready
        if !forceRefresh, !PreloadManager.shared.isComplete {
            await PreloadManager.shared.waitForCompletion(timeout: 4.0)
        }

        let me = await SupabaseManager.shared.currentUserId()

        // LOGGED OUT: Skip fetching and show the compact feed banner instead.
        if me == nil {
            await MainActor.run {
                self.applyFeatured(items: [], currentUserId: nil)
                self.updateTrendingItems(from: [], currentUserId: nil)
                self.updateHomeFeedPresentation(currentUserId: nil)
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
                    self.updateTrendingItems(from: [], currentUserId: me)
                    self.updateHomeFeedPresentation(currentUserId: me)
                }
                return
            }
        }

        let visibleNonOwnItems = makeHomeFeedItems(from: allItems, currentUserId: me)
        let nearbyItems = await DistanceService.shared.filterItemsWithinRadius(visibleNonOwnItems)

        // New Arrivals: include the user's own newly-listed items (no reviews yet)
        // so lenders can see their listings on the home feed right after publishing.
        let allVisibleItems = CommunitySafetyService.shared.visibleItems(from: allItems)
        let nearbyAllItems = await DistanceService.shared.filterItemsWithinRadius(allVisibleItems)
        let newArrivals = makeNewArrivalsItems(from: nearbyAllItems, currentUserId: me)

        await MainActor.run {
            self.applyFeatured(items: newArrivals, currentUserId: me)
            self.updateTrendingItems(from: nearbyItems, currentUserId: me)
            self.updateHomeFeedPresentation(currentUserId: me)
        }
    }

    private func makeHomeFeedItems(from items: [Item], currentUserId: String?) -> [Item] {
        items.filter { item in
            guard let currentUserId else { return true }
            return item.owner_id.caseInsensitiveCompare(currentUserId) != .orderedSame
        }
    }

    private func makeNewArrivalsItems(from items: [Item], currentUserId: String?) -> [Item] {
        // New Arrivals shows items that have no reviews yet (truly "new"),
        // sorted newest-first. The user's own items ARE included here so
        // they can see their listing appear right after publishing.
        let newItems = items.filter { item in
            let hasReviews = (item.review_count ?? 0) > 0
            return !hasReviews
        }
        return Array(
            newItems
                .sorted { lhs, rhs in
                    let lhsDate = lhs.created_at ?? .distantPast
                    let rhsDate = rhs.created_at ?? .distantPast
                    if lhsDate != rhsDate {
                        return lhsDate > rhsDate
                    }
                    return lhs.id > rhs.id
                }
                .prefix(4)
        )
    }

    /// Dynamically adjusts the homeBG (scroll content) height constraint
    /// so it wraps tightly around visible content instead of a fixed 1600pt.
    /// Also repositions the "You ❤️ Rentiwise" tagline to sit right below the last content.
    @MainActor
    func recalculateScrollContentHeight() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private static let loggedInHomeFeedBannerTag = 8901
    private static let loggedOutHomeFeedBannerTag = 8902

    func updateHomeFeedPresentation(currentUserId: String?) {
        let hasTrendingItems = !trendingItems.isEmpty
        let hasNewArrivals = !featuredItems.isEmpty

        trendingTitleLabel?.isHidden = !hasTrendingItems
        trendingUiView?.isHidden = !hasTrendingItems
        trendingCollectionView?.isHidden = !hasTrendingItems

        newArrivalsTitleLabel?.isHidden = !hasNewArrivals
        featuredCardsStackView?.isHidden = !hasNewArrivals

        let shouldShowFeedBanner = !hasTrendingItems && !hasNewArrivals
        shouldPreferHomeFeedEmptyBanner = shouldShowFeedBanner
        applyListingEmptyStateVisibility()
        setHomeFeedEmptyBannerVisible(shouldShowFeedBanner, isLoggedOut: currentUserId == nil)
        recalculateScrollContentHeight()
    }

    private func setHomeFeedEmptyBannerVisible(_ isVisible: Bool, isLoggedOut: Bool) {
        let expectedTag = isLoggedOut ? Self.loggedOutHomeFeedBannerTag : Self.loggedInHomeFeedBannerTag

        if !isVisible {
            removeHomeFeedEmptyBanner()
            return
        }

        if homeFeedEmptyBannerView?.tag == expectedTag {
            return
        }

        removeHomeFeedEmptyBanner()

        let banner = buildHomeFeedEmptyBannerUI(isLoggedOut: isLoggedOut)
        banner.tag = expectedTag

        if let insertIndex = contentStackView.arrangedSubviews.firstIndex(of: Homepagelastline) {
            contentStackView.insertArrangedSubview(banner, at: insertIndex)
        } else {
            contentStackView.addArrangedSubview(banner)
        }
        contentStackView.setCustomSpacing(24, after: banner)
        homeFeedEmptyBannerView = banner
    }

    func removeHomeFeedEmptyBanner() {
        guard let banner = homeFeedEmptyBannerView else { return }
        contentStackView.removeArrangedSubview(banner)
        banner.removeFromSuperview()
        homeFeedEmptyBannerView = nil
    }

    private func featuredItemSlots() -> [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?)] {
        [
            (item1Image, item1Name, item1Rate, item1Rating, item1Distance, item1owner, item1CardView, rentButton1),
            (item2Image, item2Name, item2Rate, item2Rating, item2Distance, item2owner, item2CardView, rentButton2),
            (item3Image, item3Name, item3Rate, item3Rating, item3Distance, item3owner, item3CardView, rentButton3),
            (item4Image, item4Name, item4Rate, item4Rating, item4Distance, item4owner, item4CardView, rentButton4)
        ]
    }

    func applyFeatured(items: [Item], currentUserId: String?) {
        if items.isEmpty {
            featuredCardsStackView?.isHidden = true
            for slot in featuredItemSlots() { clearFeaturedSlot(slot) }
            self.featuredItems = []
            return
        }
        featuredCardsStackView?.isHidden = false

        let slots = featuredItemSlots()

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
                await MainActor.run {
                    self.applyOwnerName(self.capitalizingFirstLetter(name), toSlotAt: slotIndex)
                }
                return
            }

            // Final fallback: "Owner"
            await MainActor.run {
                self.applyOwnerName("Owner", toSlotAt: slotIndex)
            }
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
