//
//  CategoriesViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/11/25.
//

import UIKit

final class CategoriesViewController: UIViewController {

    // MARK: - Inputs
    var category: String?

    // MARK: - Outlets (wired in AppStarting storyboard, ID: "Categories")
    @IBOutlet weak var tableViewForItem: UITableView!
    
    // MARK: - Private state
    private var items: [Item] = []
    private let service: ItemsServicing = ItemsService()
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // Empty state label
    private lazy var emptyStateLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.text = "No items in this category"
        // Add a bit of horizontal padding so long texts don’t touch edges on iPad
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = (category?.isEmpty == false) ? category : "Category"

        tableViewForItem?.dataSource = self
        tableViewForItem?.delegate = self

        // Fixed card height for every row
        tableViewForItem?.rowHeight = 150
        tableViewForItem?.estimatedRowHeight = 150

        // Visual spacing and cleaner look between cards
        tableViewForItem?.separatorStyle = .none
        tableViewForItem?.backgroundColor = .systemGroupedBackground

        // Add consistent 16pt spacing above first card and below last card
        tableViewForItem?.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)

        // Prepare empty state view (backgroundView) now so constraints can be applied
        if let table = tableViewForItem {
            let container = UIView(frame: table.bounds)
            container.backgroundColor = .clear
            container.addSubview(emptyStateLabel)
            NSLayoutConstraint.activate([
                emptyStateLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                emptyStateLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
                emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
            ])
            // Start hidden; will toggle after load
            container.isHidden = true
            table.backgroundView = container
        }

        // IMPORTANT: Do not register UITableViewCell.self for "ItemCell" anywhere,
        // or you will override the storyboard prototype cell.

        // Fetch items for the selected category
        Task { await loadItems() }
    }

    private func formattedPricePerDay(_ value: Double) -> String {
        let amount = NSNumber(value: value)
        let currency = currencyFormatter.string(from: amount) ?? "\(value)"
        return "\(currency) / day"
    }

    @MainActor
    private func reloadUI() {
        tableViewForItem?.reloadData()
        updateEmptyState()
    }

    private func presentError(_ message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func showLoading(_ show: Bool) {
        if show {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func updateEmptyState() {
        guard let table = tableViewForItem else { return }
        // If there are no items, show the label; otherwise hide.
        let shouldShow = items.isEmpty
        table.backgroundView?.isHidden = !shouldShow

        // Customize the message per category if desired
        if let cat = category, !cat.isEmpty {
            emptyStateLabel.text = "No items in \(cat)"
        } else {
            emptyStateLabel.text = "No items in this category"
        }
    }

    private func loadItems() async {
        showLoading(true)
        defer { showLoading(false) }

        do {
            let cat = category ?? ""
            let fetched = try await service.fetchItems(category: cat)
            self.items = fetched
            await MainActor.run { self.reloadUI() }
        } catch {
            await MainActor.run {
                // Keep items as-is (likely empty) and update empty state too
                self.reloadUI()
                self.presentError(error.localizedDescription)
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension CategoriesViewController: UITableViewDataSource {

    // Single section; each cell will inset its card internally to create spacing
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath) as? CategoryItemCell else {
            // Fallback if the storyboard isn’t configured yet
            let fallback = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            let item = items[indexPath.row]
            fallback.textLabel?.text = item.title
            fallback.detailTextLabel?.text = formattedPricePerDay(item.price_per_day)
            // No accessory arrow
            fallback.accessoryType = .none
            // Clear backgrounds so the table's background shows between rows
            fallback.backgroundColor = .clear
            fallback.contentView.backgroundColor = .clear
            // Ensure no clipping so shadows render
            fallback.contentView.clipsToBounds = false
            fallback.clipsToBounds = false
            return fallback
        }

        let item = items[indexPath.row]
        cell.configure(with: item, currencyFormatter: currencyFormatter)
        cell.delegate = self

        // No accessory arrow
        cell.accessoryType = .none

        // Make sure the gap color shows around the card
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        // Ensure shadow is not clipped by the cell/contentView
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false

        return cell
    }
}

// MARK: - UITableViewDelegate
extension CategoriesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedItem = items[indexPath.row]

        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }

        // Pass the selected item so the detail binds correctly
        productVC.configure(with: selectedItem)
        productVC.hidesBottomBarWhenPushed = true
        productVC.title = "Product Detail"

        if let nav = navigationController {
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
            present(productVC, animated: true)
        }
    }

    // No footers; spacing is handled by internal insets inside the cell
}

extension CategoriesViewController: CategoryItemCellDelegate {
    func categoryItemCellDidTapRent(_ cell: CategoryItemCell) {
        guard let indexPath = tableViewForItem.indexPath(for: cell) else { return }
        let item = items[indexPath.row]

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

        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(requestVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: requestVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

// MARK: - Lightweight remote image loading
private extension UIImageView {
    func setImage(from url: URL) {
        UIImageView.loadImage(from: url) { [weak self] image in
            self?.image = image
        }
    }
}
