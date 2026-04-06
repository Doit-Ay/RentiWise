// BorrowerRequestsViewController.swift
import UIKit
import Supabase

final class BorrowerRequestsViewController: UIViewController {

    // MARK: - UI
    private let headerContainer = UIView()
    private let searchBar = UISearchBar()
    private let filterButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - Data
    private var rows: [RequestWithItem] = []            // full dataset
    private var filteredRows: [RequestWithItem] = []     // displayed dataset

    // Simple status filter
    private enum StatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case active = "Active"
        case completed = "Completed"
        case cancelled = "Cancelled"
        case denied = "Denied"
    }
    private var currentStatusFilter: StatusFilter = .all {
        didSet { applyFilters() }
    }

    private var searchText: String = "" {
        didSet { applyFilters() }
    }

    // Loading state — shows skeleton placeholders while fetching
    private var isLoading = false {
        didSet {
            tableView.reloadData()
            if isLoading { tableView.backgroundView = nil }
        }
    }

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
        setupHeader()
        setupTable()
        Task { await loadRequests() }
    }

    // MARK: - Header (Search + Filter)
    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        // Search bar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search rentals"
        searchBar.delegate = self
        
        // Apply consistent styling
        searchBar.applyRentiWiseStyle()

        // Filter button
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.setTitle("Filter", for: .normal)
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        filterButton.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        filterButton.addTarget(self, action: #selector(didTapFilter), for: .touchUpInside)

        // Layout: search left, filter right
        headerContainer.addSubview(searchBar)
        headerContainer.addSubview(filterButton)

        let topGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerContainer.topAnchor.constraint(equalTo: topGuide.topAnchor),

            searchBar.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            searchBar.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            searchBar.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),

            filterButton.leadingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 8),
            filterButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            filterButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),

            // Make filter button hug its content
            filterButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        // Apply rounded corners after layout
        DispatchQueue.main.async { [weak self] in
            self?.searchBar.applyRoundedCorners()
        }
    }

    @objc private func didTapFilter() {
        let ac = UIAlertController(title: "Filter by status", message: nil, preferredStyle: .actionSheet)

        for option in StatusFilter.allCases {
            let action = UIAlertAction(title: option.rawValue, style: .default, handler: { [weak self] _ in
                self?.currentStatusFilter = option
            })
            // Show checkmark for active filter
            if option == currentStatusFilter {
                action.setValue(true, forKey: "checked")
            }
            ac.addAction(action)
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = filterButton
            pop.sourceRect = filterButton.bounds
        }
        present(ac, animated: true)
    }

    // MARK: - Table
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 140
        tableView.estimatedRowHeight = 140
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0) // small top spacing since header is present

        // Reuse existing nib/cell
        tableView.register(UINib(nibName: "LenderRequestTableViewCell", bundle: nil), forCellReuseIdentifier: "Request")
        tableView.register(SkeletonTableViewCell.self, forCellReuseIdentifier: SkeletonTableViewCell.reuseID)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data
    private func showEmptyStateIfNeeded() {
        if filteredRows.isEmpty {
            let label = UILabel()
            label.text = "No rentals yet"
            if !searchText.isEmpty || currentStatusFilter != .all {
                label.text = "No results"
            }
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16, weight: .medium)
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    private func loadRequests() async {
        isLoading = true
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isLoading = false
                self.rows = []
                self.filteredRows = []
                self.showEmptyStateIfNeeded()
                self.presentLoginAlert()
            }
            return
        }

        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """

        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("borrower_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let rows = try JSONDecoder().decode([RequestWithItem].self, from: response.data)
            await MainActor.run {
                self.isLoading = false
                self.rows = rows
                self.applyFilters()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.rows = []
                self.filteredRows = []
                self.showEmptyStateIfNeeded()
            }
        }
    }

    private func presentLoginAlert() {
        let ac = UIAlertController(title: "Sign in required", message: "Please sign in to view your rentals.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Filtering
    private func applyFilters() {
        // Start with all rows
        var result = rows

        // Status filter using canonical RentalStatus enum
        switch currentStatusFilter {
        case .all:
            break
        case .pending:
            result = result.filter { $0.rentalStatus == .pending }
        case .active:
            result = result.filter { [.accepted, .approved, .returned].contains($0.rentalStatus) }
        case .completed:
            result = result.filter { $0.rentalStatus == .completed }
        case .cancelled:
            result = result.filter { $0.rentalStatus == .cancelled }
        case .denied:
            result = result.filter { [.denied, .rejected].contains($0.rentalStatus) }
        }

        // Search text filter
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let q = trimmed.lowercased()
            result = result.filter { row in
                let title = row.items?.title.lowercased() ?? ""
                let id = row.item_id.lowercased()
                return title.contains(q) || id.contains(q)
            }
        }

        filteredRows = result
        tableView.reloadData()
        showEmptyStateIfNeeded()
    }
}

// MARK: - UISearchBarDelegate
extension BorrowerRequestsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        searchText = text
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchText = ""
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource
extension BorrowerRequestsViewController: UITableViewDataSource {
    private static let skeletonCount = 4

    func numberOfSections(in tableView: UITableView) -> Int {
        isLoading ? Self.skeletonCount : filteredRows.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            return tableView.dequeueReusableCell(withIdentifier: SkeletonTableViewCell.reuseID, for: indexPath) as! SkeletonTableViewCell
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Request", for: indexPath) as? LenderRequestTableViewCell else {
            return UITableViewCell()
        }

        let req = filteredRows[indexPath.section]

        // Name: prefer item title, fallback to item_id
        cell.itemNameRequest.text = req.items?.title ?? req.item_id
        cell.itemNameRequest.numberOfLines = 1
        cell.itemNameRequest.lineBreakMode = .byTruncatingTail

        // Rate: from items.price_per_day if available; else date range
        if let p = req.items?.price_per_day {
            let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
            cell.itemRateRequest.text = text
        } else {
            let sql = DateFormatter()
            sql.calendar = .init(identifier: .gregorian)
            sql.timeZone = .current
            sql.dateFormat = "yyyy-MM-dd"
            let display = DateFormatter()
            display.calendar = .init(identifier: .gregorian)
            display.timeZone = .current
            display.dateFormat = "d MMM yyyy"
            if let s = sql.date(from: req.start_date),
               let e = sql.date(from: req.end_date) {
                cell.itemRateRequest.text = "\(display.string(from: s)) — \(display.string(from: e))"
            } else {
                cell.itemRateRequest.text = "—"
            }
        }

        // Status label — use canonical display name for consistency
        cell.itemBorrowerRequest.text = req.rentalStatus.displayName

        // Image: first item image if any
        if let path = req.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            cell.setImage(from: url)
        } else {
            cell.itemImageRequest.image = UIImage(systemName: "photo")
            cell.itemImageRequest.tintColor = .secondaryLabel
            cell.itemImageRequest.contentMode = .scaleAspectFit
        }

        // Transparent so grouped background shows between cards
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }
}

// MARK: - UITableViewDelegate
extension BorrowerRequestsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 16 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isLoading else { return }

        let selected = filteredRows[indexPath.section]

        // Borrowers see BookingApprovalViewController (their own rental view with payment, return, extend)
        // NOT DashboardLenderRequestViewController which shows Accept/Deny buttons meant for lenders
        let nibName = "BookingApprovalViewController"
        let bookingVC: BookingApprovalViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
           Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            bookingVC = BookingApprovalViewController(nibName: nibName, bundle: nil)
        } else {
            bookingVC = BookingApprovalViewController()
        }
        bookingVC.title = "Booking Details"
        bookingVC.hidesBottomBarWhenPushed = true
        bookingVC.mode = .myRentals
        bookingVC.request = selected

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(bookingVC, animated: true)
    }
}
