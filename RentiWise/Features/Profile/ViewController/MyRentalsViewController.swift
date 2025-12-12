//
//  MyRentalsViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/12/25.
//

import UIKit
import Supabase

final class MyRentalsViewController: UIViewController {

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refresh = UIRefreshControl()

    // Top row containing a search bar (left, expands) and a Filter button (right)
    private let topBar = UIView()
    private let searchBar = UISearchBar(frame: .zero)
    private let filterButton = UIButton(type: .system)

    // MARK: - Data
    private var allRequests: [RequestWithItem] = []
    private var visibleRequests: [RequestWithItem] = []

    // Search/filter state
    private var currentQuery: String = "" { didSet { applySearchAndFilters() } }
    private var currentStatus: StatusFilter = .all { didSet { applySearchAndFilters() } }

    private enum StatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case accepted = "Accepted"
        case completed = "Completed"
        case cancelled = "Cancelled"

        static func from(raw: String) -> StatusFilter {
            let l = raw.lowercased()
            switch l {
            case "pending": return .pending
            case "accepted": return .accepted
            case "completed": return .completed
            case "cancelled": return .cancelled
            default: return .all
            }
        }
    }

    // Currency for BorrowerTableViewCell
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Rentals"
        view.backgroundColor = .secondarySystemBackground
        navigationController?.navigationBar.prefersLargeTitles = false

        setupTopBar()
        setupTable()

        Task { await loadData(showSpinner: true) }
    }

    // MARK: - UI Setup
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .secondarySystemBackground
        view.addSubview(topBar)

        // Search bar configuration
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search by item title"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search

        // Filter button on the right
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.setTitle("Filter: All", for: .normal)
        filterButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        filterButton.setTitleColor(UIColor(red: 112/255, green: 167/255, blue: 180/255, alpha: 1.0), for: .normal)
        filterButton.addTarget(self, action: #selector(didTapFilter), for: .touchUpInside)

        topBar.addSubview(searchBar)
        topBar.addSubview(filterButton)

        // Layout: search bar fills left, filter button pinned right; vertical centering
        let topBarHeight: CGFloat = 50
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: topBarHeight),

            filterButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            filterButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            searchBar.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -12),
            searchBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Table below top bar
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTable() {
        // Match Lender (RequestsList) look
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 150
        tableView.estimatedRowHeight = 150
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)

        // Register the Borrower cell from nib if available; else expect storyboard registration
        if Bundle.main.path(forResource: "BorrowerTableViewCell", ofType: "nib") != nil ||
            Bundle.main.path(forResource: "BorrowerTableViewCell", ofType: "xib") != nil {
            tableView.register(UINib(nibName: "BorrowerTableViewCell", bundle: nil), forCellReuseIdentifier: "Borrower")
        }

        tableView.dataSource = self
        tableView.delegate = self

        refresh.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh
    }

    // MARK: - Actions
    @objc private func didTapFilter() {
        let ac = UIAlertController(title: "Filter", message: nil, preferredStyle: .actionSheet)
        for status in StatusFilter.allCases {
            ac.addAction(UIAlertAction(title: status.rawValue, style: .default, handler: { [weak self] _ in
                self?.currentStatus = status
                self?.filterButton.setTitle("Filter: \(status.rawValue)", for: .normal)
            }))
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = ac.popoverPresentationController {
            pop.sourceView = filterButton
            pop.sourceRect = filterButton.bounds
        }
        present(ac, animated: true)
    }

    @objc private func didPullToRefresh() {
        Task { await loadData(showSpinner: false) }
    }

    // MARK: - Data
    private func applySearchAndFilters() {
        let statusFilter: ((RequestWithItem) -> Bool) = { [weak self] req in
            guard let self else { return true }
            switch self.currentStatus {
            case .all: return true
            case .pending: return req.status.lowercased() == "pending"
            case .accepted: return req.status.lowercased() == "accepted"
            case .completed: return req.status.lowercased() == "completed"
            case .cancelled: return req.status.lowercased() == "cancelled"
            }
        }

        let query = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let textFilter: ((RequestWithItem) -> Bool) = { req in
            guard !query.isEmpty else { return true }
            let title = req.items?.title.lowercased() ?? ""
            return title.contains(query)
        }

        visibleRequests = allRequests.filter { statusFilter($0) && textFilter($0) }
        updateEmptyStateIfNeeded()
        tableView.reloadData()
    }

    private func updateEmptyStateIfNeeded() {
        if visibleRequests.isEmpty {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16, weight: .medium)

            var base = "No rentals found"
            if currentStatus != .all {
                base = "No \(currentStatus.rawValue) rentals"
            }
            if !currentQuery.isEmpty {
                base += " for “\(currentQuery)”"
            }
            label.text = base
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    private func showLoadingInNav(_ show: Bool) {
        if show {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func presentError(_ message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func selectClause() -> String {
        // Join items(...) so we can render BorrowerTableViewCell from ItemLite
        return """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """
    }

    private func orderClauseAscending() -> Bool { false } // newest first

    private func updateOwnerLabel(for cell: BorrowerTableViewCell, with req: RequestWithItem) {
        // Owner label: show owner name (if later available) OR show status for now.
        let status = req.status.capitalized
        cell.borrowerItemOwnerName?.text = "\(status) • Owner"
    }

    // MARK: - Fetch
    private func loadData(showSpinner: Bool) async {
        if showSpinner { showLoadingInNav(true) }
        defer {
            Task { @MainActor in
                self.showLoadingInNav(false)
                self.refresh.endRefreshing()
            }
        }

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.allRequests = []
                self.visibleRequests = []
                self.applySearchAndFilters()
            }
            return
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(selectClause())
                .eq("borrower_id", value: userId)
                .order("created_at", ascending: orderClauseAscending())
                .execute()

            let rows = try JSONDecoder().decode([RequestWithItem].self, from: response.data)

            await MainActor.run {
                self.allRequests = rows
                self.applySearchAndFilters()
            }
        } catch {
            await MainActor.run {
                self.presentError(error.localizedDescription)
                self.allRequests = []
                self.visibleRequests = []
                self.applySearchAndFilters()
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension MyRentalsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { visibleRequests.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let req = visibleRequests[indexPath.section]

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Borrower") as? BorrowerTableViewCell ??
                tableView.dequeueReusableCell(withIdentifier: "Borrower", for: indexPath) as? BorrowerTableViewCell else {
            // Fallback temporary cell
            let fallback = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            fallback.textLabel?.text = req.items?.title ?? req.item_id
            fallback.detailTextLabel?.text = req.status.capitalized
            fallback.backgroundColor = .secondarySystemBackground
            fallback.contentView.backgroundColor = .secondarySystemBackground
            return fallback
        }

        if let lite = req.items {
            cell.configure(with: lite, currencyFormatter: currencyFormatter)
        } else {
            // If join failed, show minimal info
            cell.borrowerItemName?.text = req.item_id
            cell.borrowerItemRate?.text = ""
            cell.borrowerItemImage?.image = UIImage(systemName: "photo")
            cell.borrowerItemImage?.tintColor = .secondaryLabel
            cell.borrowerItemImage?.contentMode = .scaleAspectFit
        }

        updateOwnerLabel(for: cell, with: req)

        // Match Lender (Requests) look: make the area around the card match the table
        cell.backgroundColor = .secondarySystemBackground
        cell.contentView.backgroundColor = .secondarySystemBackground
        cell.clipsToBounds = false
        cell.contentView.clipsToBounds = false

        return cell
    }
}

// MARK: - UITableViewDelegate
extension MyRentalsViewController: UITableViewDelegate {
    // Spacing between cards using section footers (match Lender)
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 10 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let req = visibleRequests[indexPath.section]
        // Open ProductViewController for the item
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }

        if let lite = req.items {
            // Build a minimal Item to pass along
            let item = Item(
                id: lite.id,
                owner_id: req.owner_id,
                title: lite.title,
                description: nil,
                category: nil,
                condition: nil,
                price_per_day: lite.price_per_day,
                deposit_amount: 0,
                images: lite.images,
                is_active: true,
                created_at: nil,
                updated_at: nil
            )
            productVC.configure(with: item)
        } else {
            productVC.title = "Product Detail"
        }

        productVC.title = "Product Detail"
        productVC.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(productVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension MyRentalsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentQuery = searchText
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
