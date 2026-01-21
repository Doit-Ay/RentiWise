//
//  ProductVeiwController.swift
//  ProductDetails
//
//  Created by user@48 on 13/11/25.
//

import UIKit
import Foundation
import Supabase

final class ProductViewController: UIViewController, UIScrollViewDelegate {
    // The selected item to display. Set this before presenting/pushing.
    var selectedItem: Item?
    
    struct Review {
        let id: String
        let userId: String
        let userInitials: String
        let username: String
        let avatarURL: String?
        let comment: String
        let rating: Int
        let date: Date
    }
    
    private var reviews: [Review] = []

    // MARK: - Display mode
    enum DisplayMode {
        case normal      // viewing someone else’s item
        case ownItem     // viewing my own item (hide owner/rent/deposit/review)
    }
    var displayMode: DisplayMode = .normal {
        didSet { setupNavBarForDisplayMode() }
    }

    // Currency formatter for rates and deposits
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // Unified rating to display everywhere for now
    private let unifiedRating: Double = 4.5
    private let unifiedReviewsText: String = "(23 reviews)"

    @IBOutlet weak var heroImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel?

    @IBOutlet weak var priceLabel: UILabel?
    @IBOutlet weak var distanceLabel: UILabel?
    @IBOutlet weak var ratingValueLabel: UILabel?
    @IBOutlet weak var ratingReviewsLabel: UILabel?

    // MARK: - Description card
    @IBOutlet weak var descriptionCard: UIView!
    @IBOutlet weak var descriptionTitleLabel: UILabel?
    @IBOutlet weak var descriptionBodyLabel: UILabel?

    // MARK: - Owner card
    @IBOutlet weak var ownerCard: UIView?
    @IBOutlet weak var ownerAvatarImageView: UIImageView?
    @IBOutlet weak var ownerNameLabel: UILabel?
    @IBOutlet weak var distanceRightLabel: UILabel?
    @IBOutlet weak var ownerRating: UILabel?

    // Optional height constraint outlet (connect only if not using UIStackView)
    @IBOutlet weak var ownerCardHeight: NSLayoutConstraint?

    // MARK: - Deposit card
    @IBOutlet weak var depositCard: UIView?
    @IBOutlet weak var depositTitleLabel: UILabel?
    @IBOutlet weak var depositBodyLabel: UILabel?

    // Optional height constraint outlet (connect only if not using UIStackView)
    @IBOutlet weak var depositCardHeight: NSLayoutConstraint?

    // MARK: - Reviews section
    @IBOutlet weak var reviewsTitleLabel: UILabel?

    // Legacy single review card container you mentioned
    @IBOutlet weak var review1Card: UIView?

    // New reviews stack replacing the old fixed outlets (connect if available)
    @IBOutlet weak var reviewsStack: UIStackView?

    // MARK: - Action buttons
    @IBOutlet weak var writeAReview: UIButton?
    @IBOutlet weak var rentNowoutlet: UIButton?

    // If buttons are inside a container row, connect it and its height
    @IBOutlet weak var actionButtonsContainer: UIView?
    @IBOutlet weak var actionButtonsContainerHeight: NSLayoutConstraint?

    // Spacing constraint that directly connects Description to Reviews title/top
    // Normal value (when sections are visible) = 248, Own-item value = small (e.g., 16)
    @IBOutlet weak var descriptionAndReview: NSLayoutConstraint?

    // MARK: - Gallery (added)
    private var galleryScrollView: UIScrollView?
    private var pageControl: UIPageControl?

    // MARK: - Public API
    /// Call this to inject the item before navigation
    func configure(with item: Item) {
        self.selectedItem = item
    }

    // MARK: - Binding
    private func bindItemToUI() {
        guard let item = selectedItem else { return }
        guard isViewLoaded else { return }

        // Title
        self.title = item.title
        productNameLabel?.text = item.title

        // Setup hero area: single image vs. gallery
        setupHeroArea(with: item.images)

        // Price per day
        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        priceLabel?.text = priceText

        // Unified Rating & Reviews
        ratingValueLabel?.text = String(format: "%.1f", unifiedRating)
        ratingReviewsLabel?.text = unifiedReviewsText

        // Distance (placeholder unless you later compute from user/location)
        distanceLabel?.text = "2.3 km"
        distanceRightLabel?.text = "2.3 km"

        // Description card
        descriptionTitleLabel?.text = "Description"
        descriptionBodyLabel?.text = item.description ?? ""
        descriptionBodyLabel?.numberOfLines = 0
        descriptionBodyLabel?.preferredMaxLayoutWidth = descriptionBodyLabel?.bounds.width ?? 0

        // Deposit card text
        depositTitleLabel?.text = "Refundable Deposit"
        let depositNumber = NSNumber(value: item.deposit_amount)
        let depositText = currencyFormatter.string(from: depositNumber) ?? String(format: "₹%.2f", item.deposit_amount)
        depositBodyLabel?.text = "A \(depositText) deposit is required and will be fully refunded when the item is returned in the same condition."

        // Owner defaults
        ownerNameLabel?.text = nil
        ownerAvatarImageView?.image = nil
        ownerAvatarImageView?.backgroundColor = .secondarySystemBackground
        ownerAvatarImageView?.layer.cornerRadius = (ownerAvatarImageView?.bounds.height ?? 0) / 2
        ownerAvatarImageView?.layer.masksToBounds = true
        
        Task { [weak self] in
            await self?.fetchAndDisplayOwner(ownerId: item.owner_id)
        }

        // Reviews section title
        reviewsTitleLabel?.text = "Reviews"
        
        applyDisplayMode()
        setupNavBarForDisplayMode()

        // Load reviews from Supabase
        Task { [weak self] in
            await self?.loadReviews()
        }
    }

    private func applyDisplayMode() {
        let isOwn = (displayMode == .ownItem)

        // Hide views
        ownerCard?.isHidden = isOwn
        depositCard?.isHidden = isOwn
        writeAReview?.isHidden = isOwn
        rentNowoutlet?.isHidden = isOwn
        actionButtonsContainer?.isHidden = isOwn || ((writeAReview == nil || writeAReview?.isHidden == true) && (rentNowoutlet == nil || rentNowoutlet?.isHidden == true))

        // Collapse heights if not using a UIStackView
        if isOwn {
            ownerCardHeight?.constant = 0
            depositCardHeight?.constant = 0
            actionButtonsContainerHeight?.constant = 0

            // Make Reviews sit right after Description in own-item mode
            descriptionAndReview?.constant = 16
        } else {
            // Restore the normal spacing value between Description and Reviews
            descriptionAndReview?.constant = 248
        }

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Nav bar actions for own-item mode
    private func setupNavBarForDisplayMode() {
        guard isViewLoaded else { return }
        switch displayMode {
        case .ownItem:
            if #available(iOS 14.0, *) {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    systemItem: .action,
                    primaryAction: nil,
                    menu: nil
                )
                let image = UIImage(systemName: "ellipsis.circle")
                let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(didTapMore))
                navigationItem.rightBarButtonItem = item
            } else {
                let image = UIImage(systemName: "ellipsis") ?? UIImage(systemName: "ellipsis.circle")
                navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(didTapMore))
            }
        case .normal:
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc private func didTapMore(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.handleEdit()
        }))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            Task { await self?.confirmDeleteAndDelete() }
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.barButtonItem = sender
        }
        present(ac, animated: true)
    }

    private func handleEdit() {
        guard let item = selectedItem else { return }

        // Build a draft from the existing item
        var draft = AddItemDraft()
        draft.isEditing = true
        draft.existingItemId = item.id
        draft.existingImagePaths = item.images
        draft.title = item.title
        draft.description = item.description ?? ""
        draft.category = item.category ?? ""
        draft.condition = item.condition ?? ""
        draft.pricePerDay = item.price_per_day
        draft.depositAmount = item.deposit_amount
        draft.isActive = item.is_active

        // Download existing images (up to 4) as Data so the first screen can show them
        Task { [weak self] in
            let imageDatas = await self?.downloadImagesData(paths: item.images.prefix(4)) ?? []
            draft.images = imageDatas

            await MainActor.run {
                let vc = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
                vc.title = "Edit item"
                vc.hidesBottomBarWhenPushed = true
                vc.draft = draft
                if let nav = self?.navigationController {
                    nav.pushViewController(vc, animated: true)
                } else {
                    vc.modalPresentationStyle = .fullScreen
                    self?.present(vc, animated: true)
                }
            }
        }
    }

    private func downloadImagesData<S: Sequence>(paths: S) async -> [Data] where S.Element == String {
        var results: [Data] = []
        for path in paths {
            if let url = StorageURLBuilder.publicFileURL(for: path) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    results.append(data)
                } catch {
                    // ignore a failed image, continue
                }
            }
        }
        return results
    }

    // Fetch current user's display name and initials from Supabase auth/users table
    private func fetchCurrentUserNameAndInitials() async -> (String, String, String?) {
        do {
            let client = SupabaseManager.shared.client
            // Get current session/user
            if let session = try? await client.auth.session {
                let userId = session.user.id.uuidString
                // Try to read full_name and profile_photo_url from user_profiles (public view)
                do {
                    let response = try await client
                        .from("user_profiles")
                        .select("full_name,profile_photo_url")
                        .eq("id", value: userId)
                        .single()
                        .execute()

                    if let data = response.data as? Data {
                        struct NameDTO: Decodable { let full_name: String?; let profile_photo_url: String? }
                        if let dto = try? JSONDecoder().decode(NameDTO.self, from: data) {
                            let name = (dto.full_name?.isEmpty == false) ? dto.full_name! : (session.user.email?.split(separator: "@").first.map(String.init) ?? "Me")
                            let initials = self.makeInitials(from: name)
                            return (name, initials, dto.profile_photo_url)
                        }
                    }
                } catch {
                    // Fall through to use email or default
                }

                let emailName: String
                if let email = session.user.email, let namePart = email.split(separator: "@").first, !namePart.isEmpty {
                    emailName = String(namePart)
                } else {
                    emailName = "Me"
                }
                let initials = self.makeInitials(from: emailName)
                return (emailName, initials, nil)
            }
        }
        // No session: default placeholders
        let fallback = "Me"
        return (fallback, self.makeInitials(from: fallback), nil)
    }

    private func confirmDeleteAndDelete() async {
        await MainActor.run {
            let ac = UIAlertController(title: "Delete Item", message: "This action cannot be undone.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                Task { await self?.deleteItem() }
            }))
            self.present(ac, animated: true)
        }
    }

    private func presentError(_ message: String) {
        let ac = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    private func presentInfo(_ message: String) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            // On OK, pop back
            self?.navigationController?.popViewController(animated: true)
        }))
        present(ac, animated: true)
    }

    private func deleteItem() async {
        guard let item = selectedItem else { return }
        do {
            try await SupabaseManager.shared.client
                .from("items")
                .delete()
                .eq("id", value: item.id)
                .execute()
            await MainActor.run {
                self.presentInfo("Item deleted.")
            }
        } catch {
            await MainActor.run {
                self.presentError(error.localizedDescription)
            }
        }
    }

    private func setStars(_ starsRow: UIStackView, rating: Int) {
        starsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let count = max(0, min(5, rating))
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        for i in 0..<5 {
            let iv = UIImageView()
            iv.image = UIImage(systemName: i < count ? "star.fill" : "star", withConfiguration: config)
            iv.tintColor = .systemYellow
            iv.contentMode = .scaleAspectFit
            iv.setContentHuggingPriority(.required, for: .horizontal)
            iv.setContentCompressionResistancePriority(.required, for: .horizontal)
            starsRow.addArrangedSubview(iv)
        }
    }

    // MARK: - Owner fetch/render

    private struct OwnerDTO: Decodable {
        let id: String
        let full_name: String?
        let profile_photo_url: String?
    }

    private func fetchAndDisplayOwner(ownerId: String) async {
        do {
            let client = SupabaseManager.shared.client
            let response = try await client
                .from("user_profiles")
                .select("id,full_name,profile_photo_url")
                .eq("id", value: ownerId)
                .single()
                .execute()

            guard let data = response.data as? Data else {
                await MainActor.run { [weak self] in
                    self?.renderOwner(fullName: nil, avatarURLString: nil)
                }
                return
            }

            let dto = try JSONDecoder().decode(OwnerDTO.self, from: data)
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: dto.full_name, avatarURLString: dto.profile_photo_url)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: nil, avatarURLString: nil)
            }
        }
    }

    private func renderOwner(fullName: String?, avatarURLString: String?) {
        let name = (fullName?.isEmpty == false) ? fullName! : "Owner"
        ownerNameLabel?.text = name
        ownerRating?.text = "★ 4.5"

        if let avatar = avatarURLString, !avatar.isEmpty {
            if let url = URL(string: avatar), avatar.lowercased().hasPrefix("http") {
                UIImageView.rw_loadImage(from: url) { [weak self] img in
                    DispatchQueue.main.async {
                        if let img = img {
                            self?.ownerAvatarImageView?.image = img
                            self?.ownerAvatarImageView?.contentMode = .scaleAspectFill
                            self?.ownerAvatarImageView?.clipsToBounds = true
                        } else {
                            self?.renderOwnerInitials(fullName: name)
                        }
                    }
                }
            } else if let url = StorageURLBuilder.publicFileURL(for: avatar) {
                UIImageView.rw_loadImage(from: url) { [weak self] img in
                    DispatchQueue.main.async {
                        if let img = img {
                            self?.ownerAvatarImageView?.image = img
                            self?.ownerAvatarImageView?.contentMode = .scaleAspectFill
                            self?.ownerAvatarImageView?.clipsToBounds = true
                        } else {
                            self?.renderOwnerInitials(fullName: name)
                        }
                    }
                }
            } else {
                renderOwnerInitials(fullName: name)
            }
        } else {
            renderOwnerInitials(fullName: name)
        }
    }

    private func renderOwnerInitials(fullName: String) {
        let initials = makeInitials(from: fullName)
        let size = ownerAvatarImageView?.bounds.size == .zero || ownerAvatarImageView?.bounds.size == nil ? CGSize(width: 60, height: 60) : ownerAvatarImageView!.bounds.size
        ownerAvatarImageView?.image = drawInitialsImage(initials: initials, size: size)
        ownerAvatarImageView?.contentMode = .scaleAspectFill
        ownerAvatarImageView?.clipsToBounds = true
        ownerAvatarImageView?.backgroundColor = .clear
    }

    private func makeInitials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let first = parts.first?.first.map { String($0).uppercased() } ?? ""
        let last = parts.dropFirst().last?.first.map { String($0).uppercased() } ?? ""
        let combined = first + last
        return combined.isEmpty ? "?" : combined
    }

    private func drawInitialsImage(initials: String, size: CGSize) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(ovalIn: rect).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.4, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let textSize = (initials as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2.0,
                y: (size.height - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            (initials as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    // MARK: - Hero/Gallery setup

    private func setupHeroArea(with images: [String]) {
        // Clean up previous gallery if any
        galleryScrollView?.removeFromSuperview()
        pageControl?.removeFromSuperview()
        galleryScrollView = nil
        pageControl = nil

        // No images: show placeholder
        guard !images.isEmpty else {
            heroImageView?.isHidden = false
            heroImageView?.contentMode = .scaleAspectFill
            heroImageView?.image = UIImage(systemName: "photo")
            heroImageView?.tintColor = .secondaryLabel
            heroImageView?.backgroundColor = .secondarySystemBackground
            return
        }

        // One image: load into heroImageView
        if images.count == 1 {
            heroImageView?.isHidden = false
            heroImageView?.contentMode = .scaleAspectFill
            heroImageView?.clipsToBounds = true
            let path = images[0]
            if let url = urlForImagePath(path) {
                UIImageView.rw_loadImage(from: url) { [weak self] img in
                    self?.heroImageView?.image = img
                }
            } else {
                heroImageView?.image = UIImage(systemName: "photo")
                heroImageView?.tintColor = .secondaryLabel
                heroImageView?.backgroundColor = .secondarySystemBackground
            }
            return
        }

        // Multiple images: build a scrollable gallery
        heroImageView?.isHidden = true

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        view.addSubview(scroll)
        galleryScrollView = scroll

        // Constrain scroll view to the same frame as the heroImageView area
        if let anchorView = heroImageView {
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: anchorView.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: anchorView.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: anchorView.topAnchor),
                scroll.heightAnchor.constraint(equalTo: anchorView.heightAnchor)
            ])
        } else {
            // Fallback: top of the view if heroImageView not present
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                scroll.heightAnchor.constraint(equalToConstant: 240)
            ])
        }

        // Add image views horizontally
        var lastTrailing: NSLayoutXAxisAnchor?

        for (index, path) in images.enumerated() {
            let iv = UIImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            scroll.addSubview(iv)

            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: scroll.topAnchor),
                iv.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                iv.widthAnchor.constraint(equalTo: scroll.widthAnchor)
            ])
            if index == 0 {
                iv.leadingAnchor.constraint(equalTo: scroll.leadingAnchor).isActive = true
            } else if let prevTrailing = lastTrailing {
                iv.leadingAnchor.constraint(equalTo: prevTrailing).isActive = true
            }
            lastTrailing = iv.trailingAnchor

            if let url = urlForImagePath(path) {
                UIImageView.rw_loadImage(from: url) { image in
                    iv.image = image
                }
            }
        }

        if let lastTrailing {
            lastTrailing.constraint(equalTo: scroll.trailingAnchor).isActive = true
        }

        // Page control
        let pc = UIPageControl()
        pc.translatesAutoresizingMaskIntoConstraints = false
        pc.numberOfPages = images.count
        pc.currentPage = 0
        pc.pageIndicatorTintColor = .systemGray3
        pc.currentPageIndicatorTintColor = .label
        view.addSubview(pc)
        pageControl = pc

        // Place page control overlayed at bottom of gallery
        NSLayoutConstraint.activate([
            pc.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            pc.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -8)
        ])
    }

    private func urlForImagePath(_ path: String) -> URL? {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path)
        } else {
            return StorageURLBuilder.publicFileURL(for: path)
        }
    }

    // UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === galleryScrollView, let pc = pageControl, scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pc.currentPage = max(0, min(page, pc.numberOfPages - 1))
    }

    // MARK: - Reviews: Supabase load + render

    private struct ReviewRowDTO: Decodable {
        let id: String
        let item_id: String
        let reviewer_id: String
        let rating: Int
        let review_text: String?
        let created_at: String
    }

    private struct ReviewerDTO: Decodable {
        let full_name: String?
        let profile_photo_url: String?
    }

    private var reviewerCache: [String: ReviewerDTO] = [:]

    private func loadReviews() async {
        guard let itemId = selectedItem?.id else { return }
        do {
            let client = SupabaseManager.shared.client
            // Newest first
            let response = try await client
                .from("reviews")
                .select()
                .eq("item_id", value: itemId)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let rows = try decoder.decode([ReviewRowDTO].self, from: response.data)

            var built: [Review] = []
            for row in rows {
                let reviewerId = row.reviewer_id
                let profile = try await fetchReviewerProfile(userId: reviewerId)
                let name = (profile.full_name?.isEmpty == false) ? profile.full_name! : "User"
                let initials = makeInitials(from: name)
                // Parse created_at best-effort
                let date = iso8601ToDate(row.created_at) ?? Date()
                built.append(Review(
                    id: row.id,
                    userId: reviewerId,
                    userInitials: initials,
                    username: name,
                    avatarURL: profile.profile_photo_url,
                    comment: row.review_text ?? "",
                    rating: max(1, min(5, row.rating)),
                    date: date
                ))
            }

            await MainActor.run {
                self.reviews = built
                self.renderReviews()
            }
        } catch {
            await MainActor.run {
                self.reviews = []
                self.renderReviews()
            }
        }
    }

    private func iso8601ToDate(_ s: String) -> Date? {
        // Supabase timestamptz often decodes with ISO8601 including fractional seconds
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = df.date(from: s) { return d }
        df.formatOptions = [.withInternetDateTime]
        return df.date(from: s)
    }

    private func fetchReviewerProfile(userId: String) async throws -> ReviewerDTO {
        if let cached = reviewerCache[userId] { return cached }
        let client = SupabaseManager.shared.client
        let resp = try await client
            .from("user_profiles")
            .select("full_name,profile_photo_url")
            .eq("id", value: userId)
            .single()
            .execute()
        if let data = resp.data as? Data {
            let dto = try JSONDecoder().decode(ReviewerDTO.self, from: data)
            reviewerCache[userId] = dto
            return dto
        }
        // Fallback empty
        let dto = ReviewerDTO(full_name: nil, profile_photo_url: nil)
        reviewerCache[userId] = dto
        return dto
    }

    private func renderReviews() {
        // Choose container: prefer reviewsStack if connected, else build one inside review1Card
        let containerStack: UIStackView
        if let rs = reviewsStack {
            containerStack = rs
        } else {
            if let host = review1Card {
                host.subviews.forEach { $0.removeFromSuperview() }
                let v = UIStackView()
                v.axis = .vertical
                v.alignment = .fill
                v.spacing = 16
                v.translatesAutoresizingMaskIntoConstraints = false
                host.addSubview(v)
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 16),
                    v.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -16),
                    v.topAnchor.constraint(equalTo: host.topAnchor, constant: 16),
                    v.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -16)
                ])
                reviewsStack = v
                containerStack = v
            } else {
                let v = UIStackView()
                v.axis = .vertical
                v.alignment = .fill
                v.spacing = 16
                v.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(v)
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                    v.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                    v.topAnchor.constraint(equalTo: descriptionCard.bottomAnchor, constant: 16)
                ])
                reviewsStack = v
                containerStack = v
            }
        }

        // Clear old content
        containerStack.arrangedSubviews.forEach { sub in
            containerStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        if reviews.isEmpty {
            containerStack.addArrangedSubview(makeEmptyReviewsView())
            return
        }

        let df = DateFormatter()
        df.dateStyle = .medium

        Task {
            let currentUserId = await SupabaseManager.shared.currentUserId()
            // Debug: verify identity
            // print("[Reviews] currentUserId=\(currentUserId ?? "nil")")

            for (idx, review) in self.reviews.enumerated() {
                let card = UIView()
                card.backgroundColor = .clear

                let v = UIStackView()
                v.axis = .vertical
                v.alignment = .fill
                v.spacing = 8
                v.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(v)
                NSLayoutConstraint.activate([
                    v.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                    v.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    v.topAnchor.constraint(equalTo: card.topAnchor),
                    v.bottomAnchor.constraint(equalTo: card.bottomAnchor)
                ])

                // Top row: date (left) + Edit (right if mine)
                let topRow = UIStackView()
                topRow.axis = .horizontal
                topRow.alignment = .center
                topRow.spacing = 8

                let dateLabel = UILabel()
                dateLabel.font = .systemFont(ofSize: 13, weight: .regular)
                dateLabel.textColor = .secondaryLabel
                dateLabel.text = df.string(from: review.date)

                let spacer = UIView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                let editButton = UIButton(type: .system)
                editButton.setTitle("Edit", for: .normal)
                editButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
                editButton.addAction(UIAction(handler: { [weak self] _ in
                    self?.presentEditReview(review)
                }), for: .touchUpInside)

                // Robust author check (case-insensitive)
                let isMine = (currentUserId?.lowercased() == review.userId.lowercased())
                editButton.isHidden = !isMine
                editButton.isEnabled = isMine

                topRow.addArrangedSubview(dateLabel)
                topRow.addArrangedSubview(spacer)
                topRow.addArrangedSubview(editButton)
                v.addArrangedSubview(topRow)

                // Avatar + Name + Stars
                let row = UIStackView()
                row.axis = .horizontal
                row.alignment = .center
                row.spacing = 12

                let avatarSize: CGFloat = 36
                let avatar = UIImageView()
                avatar.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    avatar.widthAnchor.constraint(equalToConstant: avatarSize),
                    avatar.heightAnchor.constraint(equalToConstant: avatarSize)
                ])
                avatar.layer.cornerRadius = avatarSize / 2
                avatar.layer.masksToBounds = true
                avatar.contentMode = .scaleAspectFill

                if let avatarPath = review.avatarURL, !avatarPath.isEmpty {
                    if let url = urlForImagePath(avatarPath) {
                        UIImageView.rw_loadImage(from: url) { [weak avatar] img in
                            DispatchQueue.main.async {
                                if let img = img {
                                    avatar?.image = img
                                } else {
                                    avatar?.image = self.drawInitialsImage(initials: review.userInitials, size: CGSize(width: avatarSize, height: avatarSize))
                                }
                            }
                        }
                    } else {
                        avatar.image = drawInitialsImage(initials: review.userInitials, size: CGSize(width: avatarSize, height: avatarSize))
                    }
                } else {
                    avatar.image = drawInitialsImage(initials: review.userInitials, size: CGSize(width: avatarSize, height: avatarSize))
                }

                let nameLabel = UILabel()
                nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
                nameLabel.textColor = .label
                nameLabel.text = review.username
                nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

                let starsRow = UIStackView()
                starsRow.axis = .horizontal
                starsRow.alignment = .center
                starsRow.spacing = 4
                starsRow.setContentHuggingPriority(.required, for: .horizontal)
                starsRow.setContentCompressionResistancePriority(.required, for: .horizontal)
                self.setStars(starsRow, rating: review.rating)

                let gapView = UIView()
                gapView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    gapView.widthAnchor.constraint(equalToConstant: 16)
                ])
                gapView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                gapView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                row.addArrangedSubview(avatar)
                row.addArrangedSubview(nameLabel)
                row.addArrangedSubview(gapView)
                row.addArrangedSubview(starsRow)
                v.addArrangedSubview(row)

                if !review.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let commentLabel = UILabel()
                    commentLabel.numberOfLines = 0
                    commentLabel.textColor = .label
                    commentLabel.font = .systemFont(ofSize: 15, weight: .regular)
                    commentLabel.text = review.comment
                    commentLabel.setContentCompressionResistancePriority(.required, for: .vertical)
                    commentLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                    commentLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
                    v.addArrangedSubview(commentLabel)
                }

                if idx < (self.reviews.count - 1) {
                    let sep = UIView()
                    sep.backgroundColor = UIColor.systemGray4
                    sep.translatesAutoresizingMaskIntoConstraints = false
                    sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                    sep.setContentCompressionResistancePriority(.required, for: .vertical)
                    sep.setContentHuggingPriority(.required, for: .vertical)
                    v.addArrangedSubview(sep)
                }

                containerStack.addArrangedSubview(card)
            }
        }
    }

    private func makeEmptyReviewsView() -> UIView {
        let container = UIView()

        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .center
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
            v.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        let title = UILabel()
        title.text = "No reviews yet"
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .secondaryLabel
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Be the first to review this item."
        subtitle.font = .systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("Write a Review", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.addTarget(self, action: #selector(emptyStateWriteTapped), for: .touchUpInside)

        v.addArrangedSubview(title)
        v.addArrangedSubview(subtitle)
        v.addArrangedSubview(button)
        return container
    }

    @objc private func emptyStateWriteTapped() {
        // Reuse the same action as your existing write button
        if let b = writeAReview { didtappreviewbutton(b) }
    }

    // MARK: - Insert/Update reviews in Supabase

    private func insertReviewIntoSupabase(rating: Int, text: String) async throws {
        guard let itemId = selectedItem?.id else {
            throw NSError(domain: "ProductVC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing item id"])
        }
        guard let reviewerId = await SupabaseManager.shared.currentUserId() else {
            throw NSError(domain: "ProductVC", code: 2, userInfo: [NSLocalizedDescriptionKey: "You must be logged in to review."])
        }
        struct NewReviewRow: Encodable {
            let item_id: String
            let reviewer_id: String
            let rating: Int
            let review_text: String?
        }
        let row = NewReviewRow(item_id: itemId, reviewer_id: reviewerId, rating: rating, review_text: text)
        print("[InsertReview] Payload item_id=\(itemId) reviewer_id=\(reviewerId) rating=\(rating) textLen=\(text.count)")

        // Request the inserted row back to verify the DB stored the text
        let resp = try await SupabaseManager.shared.client
            .from("reviews")
            .insert(row)
            .select()
            .single()
            .execute()

        if let json = String(data: resp.data, encoding: .utf8) {
            print("[InsertReview] DB echoed row:", json)
        } else {
            print("[InsertReview] Insert succeeded; unable to stringify response.")
        }
    }

    private func updateReviewInSupabase(reviewId: String, rating: Int, text: String) async throws {
        struct Patch: Encodable {
            let rating: Int
            let review_text: String?
        }
        let payload = Patch(rating: rating, review_text: text)

        _ = try await SupabaseManager.shared.client
            .from("reviews")
            .update(payload)
            .eq("id", value: reviewId)
            .execute()
    }

    private func presentEditReview(_ review: Review) {
        let nibName = "WriteReviewViewController"
        let vc: WriteReviewViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = WriteReviewViewController(nibName: nibName, bundle: nil)
        } else {
            vc = WriteReviewViewController()
        }

        vc.title = "Edit Review"
        vc.hidesBottomBarWhenPushed = true
        vc.isEditingReview = true
        vc.initialRating = review.rating
        vc.initialText = review.comment

        vc.onReviewEdited = { [weak self] newRating, newText in
            guard let self = self else { return }
            Task {
                do {
                    try await self.updateReviewInSupabase(reviewId: review.id, rating: newRating, text: newText)
                } catch {
                    await MainActor.run { self.presentError(error.localizedDescription) }
                    return
                }

                // Update local model
                if let idx = self.reviews.firstIndex(where: { $0.id == review.id }) {
                    let old = self.reviews[idx]
                    let updated = Review(
                        id: old.id,
                        userId: old.userId,
                        userInitials: old.userInitials,
                        username: old.username,
                        avatarURL: old.avatarURL,
                        comment: newText,
                        rating: newRating,
                        date: old.date
                    )
                    await MainActor.run {
                        self.reviews[idx] = updated
                        self.renderReviews()
                    }
                }

                // Refresh from DB to stay canonical
                await self.loadReviews()
            }
        }

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            present(nav, animated: true)
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Product Detail"

        // Ensure description wraps to allow dynamic card height
        descriptionBodyLabel?.numberOfLines = 0
        
        // Clear legacy/demo reviews; real data will be loaded from Supabase
        reviews = []
        
        if selectedItem != nil { bindItemToUI() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if selectedItem != nil { bindItemToUI() }
    }

    // MARK: - Actions

    @IBAction func didTapRentNow(_ sender: UIButton) {
        guard let item = selectedItem else { return }

        let nibName = "RequestViewController"
        let requestVC: RequestViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            requestVC = RequestViewController(nibName: nibName, bundle: nil)
        } else {
            requestVC = RequestViewController()
        }

        requestVC.configure(with: item)
        requestVC.title = "Request"
        requestVC.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(requestVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: requestVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    
    @IBAction func didtappreviewbutton(_ sender: UIButton) {
        guard let item = selectedItem else { return }

        let nibName = "WriteReviewViewController"
        let reviewVC: WriteReviewViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            reviewVC = WriteReviewViewController(nibName: nibName, bundle: nil)
        } else {
            reviewVC = WriteReviewViewController()
        }

        reviewVC.title = "Write a Review"
        reviewVC.hidesBottomBarWhenPushed = true

        // Add completion handler to receive new review and update UI
        reviewVC.onReviewSubmitted = { [weak self] rating, text in
            guard let self = self else { return }
            print("[ProductVC] onReviewSubmitted rating=\(rating), textLen=\(text.count)")
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    print("[ProductVC] Will insert rating=\(rating) textLen=\(text.count)")
                    try await self.insertReviewIntoSupabase(rating: rating, text: text)
                } catch {
                    await MainActor.run {
                        // Friendly duplicate constraint message
                        let msg = error.localizedDescription.contains("duplicate key") ?
                            "You have already reviewed this item." :
                            error.localizedDescription
                        self.presentError(msg)
                    }
                    return
                }
                // Build local review row for immediate UI update
                let (displayName, initials, avatarURL) = await self.fetchCurrentUserNameAndInitials()
                let newReview = Review(
                    id: UUID().uuidString,
                    userId: await SupabaseManager.shared.currentUserId() ?? "",
                    userInitials: initials,
                    username: displayName,
                    avatarURL: avatarURL,
                    comment: text,
                    rating: rating,
                    date: Date()
                )
                await MainActor.run {
                    self.reviews.insert(newReview, at: 0)
                    self.renderReviews()
                }
                // Also refresh from DB to ensure canonical ordering/fields
                Task { [weak self] in
                    await self?.loadReviews()
                }
            }
        }

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(reviewVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: reviewVC)
            nav.modalPresentationStyle = .formSheet
            present(nav, animated: true)
        }
    }
}

