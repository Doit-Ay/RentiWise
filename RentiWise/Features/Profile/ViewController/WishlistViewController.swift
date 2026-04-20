//
//  WishlistViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class WishlistViewController: UITableViewController {
    
    private var items: [Item] = []
    private var isLoading = false
    private var errorMessage: String?
    
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Wishlist"
        
        tableView.register(WishlistCell.self, forCellReuseIdentifier: "WishlistCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SkeletonTableViewCell.self, forCellReuseIdentifier: SkeletonTableViewCell.reuseID)
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        
        // Remove extra side insets so the only visible gap is the cell card’s 20pt
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.separatorInset = .zero
        tableView.layoutMargins = .zero
        tableView.directionalLayoutMargins = .zero
        tableView.insetsContentViewsToSafeArea = false
        tableView.cellLayoutMarginsFollowReadableWidth = false
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSafetyRefresh),
            name: CommunitySafetyService.blockedUsersDidChangeNotification,
            object: nil
        )
        
        Task { await loadWishlist() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    @objc private func handleRefresh() {
        Task {
            await loadWishlist()
            await MainActor.run {
                refreshControl?.endRefreshing()
            }
        }
    }

    @objc private func handleSafetyRefresh() {
        items = CommunitySafetyService.shared.visibleItems(from: items)
        tableView.reloadData()
    }
    
    private func loadWishlist() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                tableView.reloadData()
            }
        }
        
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                errorMessage = "Please sign in to view your wishlist."
            }
            return
        }
        
        struct WishRow: Decodable { let item_id: String }
        do {
            let client = SupabaseManager.shared.client
            let resp = try await client
                .from("wishlist")
                .select("item_id")
                .eq("user_id", value: userId)
                .execute()
            let wishRows = try JSONDecoder().decode([WishRow].self, from: resp.data)
            let itemIds = wishRows.map { $0.item_id }
            
            if itemIds.isEmpty {
                await MainActor.run { self.items = [] }
                return
            }
            
            let itemsResp = try await client
                .from("items")
                .select()
                .in("id", values: itemIds)
                .execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetched = try decoder.decode([Item].self, from: itemsResp.data)
            let visibleItems = CommunitySafetyService.shared.visibleItems(from: fetched)
            await MainActor.run { self.items = visibleItems }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading { return 4 }
        if (items.isEmpty || errorMessage != nil) && !isLoading { return 1 } // Empty state
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SkeletonTableViewCell.reuseID, for: indexPath) as? SkeletonTableViewCell else {
                assertionFailure("Could not dequeue SkeletonTableViewCell")
                return UITableViewCell()
            }
            cell.preservesSuperviewLayoutMargins = false
            cell.layoutMargins = .zero
            return cell
        }

        if (items.isEmpty || errorMessage != nil) && !isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.backgroundColor = .clear
            cell.textLabel?.text = nil // Clear any default text
            // Remove inherited margins
            cell.preservesSuperviewLayoutMargins = false
            cell.layoutMargins = .zero
            cell.directionalLayoutMargins = .zero
            
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 16
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            
            // Larger, more prominent heart icon
            let icon = UIImageView(image: UIImage(systemName: "heart.fill"))
            icon.contentMode = .scaleAspectFit
            icon.tintColor = brandTeal.withAlphaComponent(0.3)
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 80).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 80).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = "Your Wishlist is Empty"
            titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
            titleLabel.textColor = .label
            
            let subtitleLabel = UILabel()
            subtitleLabel.text = "Start adding items you love!\nExplore our catalog and tap the heart icon."
            subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.numberOfLines = 0
            subtitleLabel.textAlignment = .center
            
            stack.addArrangedSubview(icon)
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(subtitleLabel)
            
            if let errorMessage {
                let errorLabel = UILabel()
                errorLabel.text = errorMessage
                errorLabel.textColor = .systemRed
                errorLabel.font = .preferredFont(forTextStyle: .footnote)
                errorLabel.numberOfLines = 0
                errorLabel.textAlignment = .center
                stack.addArrangedSubview(errorLabel)
            }
            
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: cell.contentView.leadingAnchor, constant: 32),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -32),
                stack.topAnchor.constraint(greaterThanOrEqualTo: cell.contentView.topAnchor, constant: 40),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: cell.contentView.bottomAnchor, constant: -40)
            ])
            
            cell.selectionStyle = .none
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "WishlistCell", for: indexPath) as? WishlistCell else {
            assertionFailure("Could not dequeue WishlistCell")
            return UITableViewCell()
        }
        // Remove inherited margins so the card’s own 20pt is the only side gap
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero
        cell.directionalLayoutMargins = .zero
        guard indexPath.row < items.count else {
            return cell
        }
        
        let item = items[indexPath.row]
        cell.configure(with: item, brandTeal: brandTeal)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isLoading else { return }
        guard indexPath.row < items.count else { return }
        let item = items[indexPath.row]
        
        let nibName = "ProductViewController"
        let vc: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            vc = ProductViewController()
        }
        vc.configure(with: item)
        vc.title = "Product Detail"
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isLoading { return 110 }
        if (items.isEmpty || errorMessage != nil) && !isLoading {
            return 350
        }
        return UITableView.automaticDimension
    }
}

// MARK: - Wishlist Cell

private class WishlistCell: UITableViewCell {
    
    private let itemImageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let heartIcon = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Card container for modern look
        let cardView = UIView()
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        // Image view - larger and more prominent
        itemImageView.contentMode = .scaleAspectFill
        itemImageView.clipsToBounds = true
        itemImageView.layer.cornerRadius = 10
        itemImageView.backgroundColor = .secondarySystemBackground
        itemImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(itemImageView)
        
        // Labels stack
        let stack = UIStackView(arrangedSubviews: [titleLabel, priceLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        
        priceLabel.font = .systemFont(ofSize: 13, weight: .medium)
        priceLabel.textColor = .secondaryLabel
        
        // Heart icon
        heartIcon.image = UIImage(systemName: "heart.fill")
        heartIcon.contentMode = .scaleAspectFit
        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(heartIcon)
        
        NSLayoutConstraint.activate([
            // Card constraints - 20px from sides
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Image - larger size
            itemImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            itemImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            itemImageView.widthAnchor.constraint(equalToConstant: 90),
            itemImageView.heightAnchor.constraint(equalToConstant: 90),
            
            // Stack
            stack.leadingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: 16),
            stack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: heartIcon.leadingAnchor, constant: -12),
            
            // Heart icon
            heartIcon.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            heartIcon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 26),
            heartIcon.heightAnchor.constraint(equalToConstant: 26),
            
            // Card height
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])
    }
    
    func configure(with item: Item, brandTeal: UIColor) {
        titleLabel.text = item.title
        
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let amount = NSNumber(value: item.price_per_day)
        let price = nf.string(from: amount) ?? String(format: "%.2f", item.price_per_day)
        priceLabel.text = "\(price) / day"
        
        heartIcon.tintColor = brandTeal
        
        // Load image
        if let imagePath = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: imagePath) {
            loadImage(from: url)
        } else {
            itemImageView.image = UIImage(systemName: "photo")
            itemImageView.tintColor = .secondaryLabel
        }
    }
    
    private func loadImage(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.itemImageView.image = image
                    }
                }
            } catch {
                await MainActor.run {
                    self.itemImageView.image = UIImage(systemName: "photo")
                    self.itemImageView.tintColor = .secondaryLabel
                }
            }
        }
    }
}
