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

        static func from(raw: String) -> StatusFilter {
            let l = raw.lowercased()
            switch l {
            case "pending": return .pending
            case "accepted": return .accepted
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
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        navigationController?.navigationBar.isTranslucent = false
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        setupTopBar()
        setupTable()

        Task { await loadData(showSpinner: true) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = "My Rentals"
    }

    // MARK: - UI Setup
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .systemGroupedBackground
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

            searchBar.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8),
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
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 150
        tableView.estimatedRowHeight = 150
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero

        tableView.sectionHeaderHeight = .leastNormalMagnitude
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0

        // Register the Borrower cell from nib if available; else expect storyboard registration
        if Bundle.main.path(forResource: "BorrowerTableViewCell", ofType: "nib") != nil ||
            Bundle.main.path(forResource: "BorrowerTableViewCell", ofType: "xib") != nil {
            tableView.register(UINib(nibName: "BorrowerTableViewCell", bundle: nil), forCellReuseIdentifier: "Borrower")
        }

        tableView.dataSource = self
        tableView.delegate = self

        refresh.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh

        if let header = tableView.tableHeaderView {
            header.backgroundColor = .systemGroupedBackground
        }
        let footer = UIView(frame: .zero)
        footer.backgroundColor = .systemGroupedBackground
        tableView.tableFooterView = footer
    }

    // MARK: - Actions
    @objc private func didTapFilter() {
        let ac = UIAlertController(title: "Filter", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: StatusFilter.all.rawValue, style: .default, handler: { [weak self] _ in
            self?.currentStatus = .all
            self?.filterButton.setTitle("Filter: All", for: .normal)
        }))
        ac.addAction(UIAlertAction(title: StatusFilter.accepted.rawValue, style: .default, handler: { [weak self] _ in
            self?.currentStatus = .accepted
            self?.filterButton.setTitle("Filter: Accepted", for: .normal)
        }))
        ac.addAction(UIAlertAction(title: StatusFilter.pending.rawValue, style: .default, handler: { [weak self] _ in
            self?.currentStatus = .pending
            self?.filterButton.setTitle("Filter: Pending", for: .normal)
        }))

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
        // Owner label: show "Owner • Status" (removed "From:")
        let status = req.status.capitalized
        cell.borrowerItemOwnerName?.text = "Owner • \(status)"
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
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleRequests.count }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let req = visibleRequests[indexPath.row]

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Borrower") as? BorrowerTableViewCell ??
                tableView.dequeueReusableCell(withIdentifier: "Borrower", for: indexPath) as? BorrowerTableViewCell else {
            // Fallback temporary cell
            let fallback = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            fallback.textLabel?.text = req.items?.title ?? req.item_id
            fallback.detailTextLabel?.text = req.status.capitalized
            fallback.backgroundColor = .clear
            fallback.contentView.backgroundColor = .clear
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

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }
}

// MARK: - UITableViewDelegate
extension MyRentalsViewController: UITableViewDelegate {
    // Spacing between cards using section footers (match Lender)
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let cancel = UIContextualAction(style: .destructive, title: "Cancel") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            // Remove from data sources
            let removed = self.visibleRequests.remove(at: indexPath.row)
            if let idx = self.allRequests.firstIndex(where: { $0.id == removed.id }) {
                self.allRequests.remove(at: idx)
            }
            // Update table by deleting the row
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }, completion: { _ in
                self.updateEmptyStateIfNeeded()
            })
            completion(true)
        }
        cancel.backgroundColor = .systemRed
        let config = UISwipeActionsConfiguration(actions: [cancel])
        config.performsFirstActionWithFullSwipe = true
        return config
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Navigate to BookingApprovalViewController when a card is tapped
        let nibName = "BookingApprovalViewController"
        let bookingVC: BookingApprovalViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            bookingVC = BookingApprovalViewController(nibName: nibName, bundle: nil)
        } else {
            bookingVC = BookingApprovalViewController()
        }

        bookingVC.title = "Booking Approval"
        bookingVC.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(bookingVC, animated: true)
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
