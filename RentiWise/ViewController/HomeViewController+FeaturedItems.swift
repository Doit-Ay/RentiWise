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

    func loadFeaturedItems() async {
        do {
            let allItems = try await itemsService.fetchItems(category: "")
            let items = Array(allItems.prefix(4))

            // Pre-warm distance cache concurrently for ALL fetched items.
            Task.detached(priority: .utility) {
                await withTaskGroup(of: Void.self) { group in
                    for item in allItems {
                        group.addTask {
                            _ = await DistanceService.shared.distanceText(for: item)
                        }
                    }
                }
            }

            await MainActor.run {
                self.applyFeatured(items: items)
                self.updateTrendingItems(from: allItems)
            }
        } catch {
            await MainActor.run {
                self.applyFeatured(items: [])
            }
        }
    }

    func applyFeatured(items: [Item]) {
        let slots: [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?)] = [
            (item1Image, item1Name, item1Rate, item1Rating, item1Distance, item1owner, item1CardView, rentButton1),
            (item2Image, item2Name, item2Rate, item2Rating, item2Distance, item2owner, item2CardView, rentButton2),
            (item3Image, item3Name, item3Rate, item3Rating, item3Distance, item3owner, item3CardView, rentButton3),
            (item4Image, item4Name, item4Rate, item4Rating, item4Distance, item4owner, item4CardView, rentButton4)
        ]

        for (i, slot) in slots.enumerated() {
            if i < items.count {
                configureFeaturedSlot(slot, with: items[i])
                // Resolve and set owner name for this slot
                resolveOwnerName(for: items[i].owner_id, slotIndex: i)

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
    }

    func configureFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?, UILabel?, UIView?, UIButton?), with item: Item) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel, ownerLabel, cardView, rentButton) = slot

        cardView?.isHidden = false
        rentButton?.isEnabled = true
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
