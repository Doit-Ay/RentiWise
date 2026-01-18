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
        let userInitials: String
        let username: String
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

    // MARK: - Reviews section (superseded by reviewsStack)
    @IBOutlet weak var reviewsTitleLabel: UILabel?

    // Old review outlets (superseded by reviewsStack)
    // Review 1 (Alex K.)
    @IBOutlet weak var review1Card: UIView?
    @IBOutlet weak var review1DateLabel: UILabel?
    @IBOutlet weak var r1star1: UIImageView?
    @IBOutlet weak var r1star2: UIImageView?
    @IBOutlet weak var r1star3: UIImageView?
    @IBOutlet weak var r1star4: UIImageView?
    @IBOutlet weak var r1star5: UIImageView?
    @IBOutlet weak var r1AvatarImageView: UIImageView?
    @IBOutlet weak var r1NameLabel: UILabel?
    @IBOutlet weak var r1CommentLabel: UILabel?

    // Review 2 (Emily R.)
    @IBOutlet weak var review2Card: UIView?
    @IBOutlet weak var review2DateLabel: UILabel?
    @IBOutlet weak var r2star1: UIImageView?
    @IBOutlet weak var r2star2: UIImageView?
    @IBOutlet weak var r2star3: UIImageView?
    @IBOutlet weak var r2star4: UIImageView?
    @IBOutlet weak var r2star5: UIImageView?
    @IBOutlet weak var r2AvatarImageView: UIImageView?
    @IBOutlet weak var r2NameLabel: UILabel?
    @IBOutlet weak var r2CommentLabel: UILabel?

    // New reviews stack replacing the above
    // Make sure to connect this outlet in Interface Builder to avoid it being nil
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
    private func fetchCurrentUserNameAndInitials() async -> (String, String) {
        do {
            let client = SupabaseManager.shared.client
            // Get current session/user
            if let session = try? await client.auth.session, let userId = session.user.id.uuidString as String? {
                // Try to read full_name from user_profiles (public view)
                do {
                    let response = try await client
                        .from("user_profiles")
                        .select("full_name")
                        .eq("id", value: userId)
                        .single()
                        .execute()

                    if let data = response.data as? Data {
                        struct NameDTO: Decodable { let full_name: String? }
                        if let dto = try? JSONDecoder().decode(NameDTO.self, from: data) {
                            let name = (dto.full_name?.isEmpty == false) ? dto.full_name! : "Me"
                            let initials = self.makeInitials(from: name)
                            return (name, initials)
                        }
                    }
                } catch {
                    // Fall through to use email or default
                }

                // Fallback to email username or generic
                let emailName: String
                if let email = session.user.email, let namePart = email.split(separator: "@").first, !namePart.isEmpty {
                    emailName = String(namePart)
                } else {
                    emailName = "Me"
                }
                let initials = self.makeInitials(from: emailName)
                return (emailName, initials)
            }
        }
        // No session: default placeholders
        let fallback = "Me"
        return (fallback, self.makeInitials(from: fallback))
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

    private func setStars(_ stars: [UIImageView?], to rating: Double) {
        let full = Int(floor(rating))
        let hasHalf = (rating - Double(full)) >= 0.5
        for i in 0..<stars.count {
            let imageView = stars[i]
            let imageName: String
            if i < full {
                imageName = "star.fill"
            } else if i == full && hasHalf {
                imageName = "star.leadinghalf.filled"
            } else {
                imageName = "star"
            }
            imageView?.image = UIImage(systemName: imageName)
            imageView?.tintColor = .systemYellow
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
                UIImageView.loadImage(from: url) { [weak self] img in
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
                UIImageView.loadImage(from: url) { [weak self] img in
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
                UIImageView.loadImage(from: url) { [weak self] img in
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
        var imageViews: [UIImageView] = []

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
            imageViews.append(iv)

            if let url = urlForImagePath(path) {
                UIImageView.loadImage(from: url) { image in
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

    // MARK: - Hero/Gallery setup end

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Product Detail"

        // Ensure description wraps to allow dynamic card height
        descriptionBodyLabel?.numberOfLines = 0
        
        // Setup initial reviews for demo
        reviews = [
            Review(userInitials: "AK", username: "Alex K.", comment: "Great quality and easy pickup.", rating: 5, date: Date(timeIntervalSinceNow: -86400)),
            Review(userInitials: "ER", username: "Emily R.", comment: "Worked as expected. Would rent again.", rating: 4, date: Date(timeIntervalSinceNow: -3600*48))
        ]
        
        r1CommentLabel?.numberOfLines = 0
        r2CommentLabel?.numberOfLines = 0
        
        refreshReviewsUI()

        if selectedItem != nil { bindItemToUI() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if selectedItem != nil { bindItemToUI() }
    }
    
    private func refreshReviewsUI() {
        // Show up to 2 reviews
        let reviewCards = [
            (card: review1Card, dateLabel: review1DateLabel, nameLabel: r1NameLabel, commentLabel: r1CommentLabel, stars: [r1star1, r1star2, r1star3, r1star4, r1star5], avatarImageView: r1AvatarImageView),
            (card: review2Card, dateLabel: review2DateLabel, nameLabel: r2NameLabel, commentLabel: r2CommentLabel, stars: [r2star1, r2star2, r2star3, r2star4, r2star5], avatarImageView: r2AvatarImageView)
        ]
        let df = DateFormatter()
        df.dateStyle = .medium
        for (i, cardData) in reviewCards.enumerated() {
            if i < reviews.count {
                let review = reviews[i]
                cardData.card?.isHidden = false
                cardData.nameLabel?.isHidden = false
                cardData.commentLabel?.isHidden = false
                cardData.commentLabel?.numberOfLines = 0
                cardData.dateLabel?.text = df.string(from: review.date)
                cardData.nameLabel?.text = review.username
                cardData.commentLabel?.text = review.comment
                cardData.commentLabel?.textColor = .label
                cardData.commentLabel?.preferredMaxLayoutWidth = cardData.commentLabel?.bounds.width ?? 0
                setStars(cardData.stars, to: Double(review.rating))
                // Set initials/avatar
                let initials = review.userInitials
                cardData.avatarImageView?.image = drawInitialsImage(initials: initials, size: CGSize(width: 36, height: 36))
                cardData.card?.setNeedsLayout()
                cardData.card?.layoutIfNeeded()
            } else {
                cardData.card?.isHidden = true
                cardData.nameLabel?.isHidden = true
                cardData.commentLabel?.isHidden = true
            }
        }
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }

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
            Task { [weak self] in
                guard let self = self else { return }
                let (displayName, initials) = await self.fetchCurrentUserNameAndInitials()
                let newReview = Review(
                    userInitials: initials,
                    username: displayName,
                    comment: text,
                    rating: rating,
                    date: Date()
                )
                await MainActor.run {
                    self.reviews.insert(newReview, at: 0)
                    self.refreshReviewsUI()
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

