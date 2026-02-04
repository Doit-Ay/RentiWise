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
        tableView.backgroundColor = .systemGroupedBackground
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        Task { await loadWishlist() }
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
            await MainActor.run { self.items = fetched }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if errorMessage != nil { return 1 }
        if items.isEmpty && !isLoading { return 1 } // Empty state
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let errorMessage {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return cell
        }
        
        if items.isEmpty && !isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 12
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            
            let icon = UIImageView(image: UIImage(systemName: "heart"))
            icon.contentMode = .scaleAspectFit
            icon.tintColor = .secondaryLabel
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 36).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = "Wishlist"
            titleLabel.font = .preferredFont(forTextStyle: .headline)
            
            let subtitleLabel = UILabel()
            subtitleLabel.text = "Add items to your wishlist from Explore."
            subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
            subtitleLabel.textColor = .secondaryLabel
            
            stack.addArrangedSubview(icon)
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(subtitleLabel)
            
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                stack.topAnchor.constraint(greaterThanOrEqualTo: cell.contentView.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: cell.contentView.bottomAnchor, constant: -24)
            ])
            
            cell.selectionStyle = .none
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "WishlistCell", for: indexPath) as! WishlistCell
        let item = items[indexPath.row]
        cell.configure(with: item, brandTeal: brandTeal)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
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
        if items.isEmpty && !isLoading && errorMessage == nil {
            return 200
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
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        // Image view
        itemImageView.contentMode = .scaleAspectFill
        itemImageView.clipsToBounds = true
        itemImageView.layer.cornerRadius = 8
        itemImageView.backgroundColor = .secondarySystemBackground
        itemImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(itemImageView)
        
        // Labels stack
        let stack = UIStackView(arrangedSubviews: [titleLabel, priceLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        
        priceLabel.font = .preferredFont(forTextStyle: .subheadline)
        priceLabel.textColor = .secondaryLabel
        
        // Heart icon
        heartIcon.image = UIImage(systemName: "heart.fill")
        heartIcon.contentMode = .scaleAspectFit
        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heartIcon)
        
        NSLayoutConstraint.activate([
            itemImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            itemImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            itemImageView.widthAnchor.constraint(equalToConstant: 60),
            itemImageView.heightAnchor.constraint(equalToConstant: 60),
            
            stack.leadingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: 12),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: heartIcon.leadingAnchor, constant: -8),
            
            heartIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            heartIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 22),
            heartIcon.heightAnchor.constraint(equalToConstant: 22),
            
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
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
