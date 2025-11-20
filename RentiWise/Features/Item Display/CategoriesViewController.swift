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
        tableViewForItem?.rowHeight = 160
        tableViewForItem?.estimatedRowHeight = 160

        // Visual spacing and cleaner look between cards
        tableViewForItem?.separatorStyle = .none
        tableViewForItem?.backgroundColor = .systemGroupedBackground

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
                self.presentError(error.localizedDescription)
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension CategoriesViewController: UITableViewDataSource {

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
            return fallback
        }

        let item = items[indexPath.row]
        cell.configure(with: item, currencyFormatter: currencyFormatter)

        // No accessory arrow
        cell.accessoryType = .none

        // Make sure the gap color shows around the card
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

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
        productVC.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
            present(productVC, animated: true)
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
