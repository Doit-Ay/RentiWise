//
//  PaymentHistoryViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class PaymentHistoryViewController: UITableViewController {
    
    private var items: [PaymentHistoryItem] = []
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
        
        title = "Payment History"
        
        tableView.register(PaymentHistoryCell.self, forCellReuseIdentifier: "PaymentCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        Task { await load() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    @objc private func handleRefresh() {
        Task {
            await load()
            await MainActor.run {
                refreshControl?.endRefreshing()
            }
        }
    }
    
    private func load() async {
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
        
        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "PaymentHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please sign in to view your payments."])
            }
            
            let client = SupabaseManager.shared.client
            let resp = try await client
                .from("payments")
                .select("id,total_amount,status,provider,created_at,items(title,category)")
                .eq("borrower_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            
            struct ItemInfo: Decodable { let title: String?; let category: String? }
            struct PaymentDec: Decodable {
                let id: String
                let total_amount: Double
                let status: String
                let provider: String
                let created_at: Date
                let items: ItemInfo?
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let rows = try decoder.decode([PaymentDec].self, from: resp.data)
            let mapped = rows.map { row in
                PaymentHistoryItem(
                    id: row.id,
                    amount: row.total_amount,
                    status: row.status,
                    createdAt: row.created_at,
                    provider: row.provider,
                    itemTitle: row.items?.title ?? "",
                    itemCategory: row.items?.category ?? ""
                )
            }
            await MainActor.run { self.items = mapped }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if errorMessage != nil { return 1 }
        if isLoading { return 1 }
        return groupedByDayKeys().count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if errorMessage != nil { return 1 }
        if isLoading { return 1 }
        
        let keys = groupedByDayKeys()
        guard section < keys.count else { return 0 }
        return itemsForDay(keys[section]).count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if errorMessage != nil || isLoading { return nil }
        
        let keys = groupedByDayKeys()
        guard section < keys.count else { return nil }
        return sectionTitle(for: keys[section])
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let errorMessage {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            return cell
        }
        
        if isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = nil
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.center = CGPoint(x: tableView.bounds.width / 2, y: 22)
            cell.contentView.addSubview(spinner)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            return cell
        }
        
        let keys = groupedByDayKeys()
        guard indexPath.section < keys.count else {
            return tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        let itemsForSection = itemsForDay(keys[indexPath.section])
        guard indexPath.row < itemsForSection.count else {
            return tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        let item = itemsForSection[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PaymentCell", for: indexPath) as! PaymentHistoryCell
        cell.configure(with: item, brandTeal: brandTeal)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if errorMessage != nil || isLoading {
            return 44
        }
        return UITableView.automaticDimension
    }
    
    // MARK: - Helpers
    
    private func groupedByDayKeys() -> [String] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let keys = Set(items.map { df.string(from: $0.createdAt) })
        return keys.sorted(by: >)
    }
    
    private func itemsForDay(_ key: String) -> [PaymentHistoryItem] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return items.filter { df.string(from: $0.createdAt) == key }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private func sectionTitle(for key: String) -> String {
        let inDF = DateFormatter()
        inDF.dateFormat = "yyyy-MM-dd"
        let outDF = DateFormatter()
        outDF.dateStyle = .medium
        outDF.timeStyle = .none
        if let d = inDF.date(from: key) {
            return outDF.string(from: d)
        }
        return key
    }
}

// MARK: - Payment History Cell

private class PaymentHistoryCell: UITableViewCell {
    
    private let cardView = UIView()
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let providerLabel = UILabel()
    private let amountLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Card view with shadow
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowRadius = 6
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        // Icon container
        iconContainer.backgroundColor = .secondarySystemBackground
        iconContainer.layer.cornerRadius = 8
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconContainer)
        
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        
        // Labels stack
        let leftStack = UIStackView(arrangedSubviews: [titleLabel, categoryLabel, providerLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 4
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(leftStack)
        
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        
        categoryLabel.font = .preferredFont(forTextStyle: .subheadline)
        categoryLabel.textColor = .secondaryLabel
        categoryLabel.numberOfLines = 1
        
        providerLabel.font = .preferredFont(forTextStyle: .footnote)
        providerLabel.textColor = .secondaryLabel
        providerLabel.numberOfLines = 1
        
        // Amount label
        amountLabel.font = .preferredFont(forTextStyle: .headline)
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(amountLabel)
        
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 361),
            cardView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            leftStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            leftStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            
            amountLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            amountLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
    }
    
    func configure(with item: PaymentHistoryItem, brandTeal: UIColor) {
        titleLabel.text = item.itemTitle.isEmpty ? "Item" : item.itemTitle
        categoryLabel.text = item.itemCategory
        categoryLabel.isHidden = item.itemCategory.isEmpty
        
        let timeText = timeText(item.createdAt)
        providerLabel.text = "\(prettyProvider(item.provider)) • \(timeText)"
        
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        amountLabel.text = nf.string(from: NSNumber(value: item.amount)) ?? "\(item.amount)"
        
        iconView.image = UIImage(systemName: iconForProvider(item.provider))
        iconView.tintColor = brandTeal
    }
    
    private func timeText(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
    
    private func iconForProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "apple_pay": return "apple.logo"
        case "card": return "creditcard"
        case "cod": return "banknote"
        default: return "creditcard"
        }
    }
    
    private func prettyProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "apple_pay": return "Apple Pay"
        case "card": return "Card"
        case "cod": return "Cash on Delivery"
        default: return provider.capitalized
        }
    }
}

// MARK: - Payment History Item

private struct PaymentHistoryItem: Identifiable {
    let id: String
    let amount: Double
    let status: String
    let createdAt: Date
    let provider: String
    let itemTitle: String
    let itemCategory: String
}
