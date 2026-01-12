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
    private let searchBar = UISearchBar()
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
        case approved = "Approved"
    }

    // Currency for price text (rounded ₹ like screenshot)
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    // Date formatters
    private lazy var sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    private lazy var displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure this VC hides the tab bar when pushed (navigation stack)
        hidesBottomBarWhenPushed = true

        // Title (plural)
        title = "My Rentals"

        // Backgrounds
        view.backgroundColor = .systemGroupedBackground

        // Nav bar appearance and visibility (systemGroupedBackground)
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = .systemGroupedBackground
        navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
        navigationController?.setNavigationBarHidden(false, animated: false)

        // Right bar "Add" action (placeholder)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))

        setupTopBar()
        setupTable()

        Task { await loadData(showSpinner: true) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Make sure nav bar is visible and title is set, and re-apply opaque appearance defensively
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = "My Rentals"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = .systemGroupedBackground
        navigationController?.navigationBar.backgroundColor = .systemGroupedBackground
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep bottom insets zero so the table reaches the very bottom
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - UI Setup
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .systemGroupedBackground
        view.addSubview(topBar)

        // Search bar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search rentals"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        if #available(iOS 13.0, *) {
            let tf = searchBar.searchTextField
            tf.backgroundColor = .secondarySystemBackground
            tf.clearButtonMode = .whileEditing
        }

        // Filter button (circular icon)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        filterButton.tintColor = UIColor.label
        filterButton.backgroundColor = UIColor.secondarySystemBackground
        filterButton.layer.cornerRadius = 20
        filterButton.layer.masksToBounds = true
        filterButton.accessibilityLabel = "Filter rentals"
        filterButton.addTarget(self, action: #selector(didTapFilter), for: .touchUpInside)

        topBar.addSubview(searchBar)
        topBar.addSubview(filterButton)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 60),

            filterButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            filterButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: 40),
            filterButton.heightAnchor.constraint(equalToConstant: 40),

            searchBar.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -10),
            searchBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 36)
        ])

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Pin to the very bottom of the view so it fills the screen
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTable() {
        // Card list look
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
        tableView.sectionHeaderHeight = .leastNormalMagnitude
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0

        tableView.register(UINib(nibName: "BorrowerTableViewCell", bundle: nil), forCellReuseIdentifier: "Borrower")

        tableView.dataSource = self
        tableView.delegate = self

        // Let content extend to bottom; manage insets manually
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }

        // Top padding for breathing room below the topBar; zero bottom so it reaches the end
        tableView.contentInset = UIEdgeInsets(top: 70, left: 0, bottom: 0, right: 0)
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 70, left: 0, bottom: 0, right: 0)

        // Explicitly zero any extra controller safe-area bottom inset
        self.additionalSafeAreaInsets.bottom = 0

        refresh.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh

        tableView.tableFooterView = UIView(frame: .zero)
    }

    // MARK: - Actions
    @objc private func didTapAdd() {
        let a = UIAlertController(title: "Add Listing", message: "This will open the add listing flow.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    @objc private func didTapFilter() {
        let ac = UIAlertController(title: "Filter rentals", message: nil, preferredStyle: .actionSheet)
        for status in [StatusFilter.all, .approved, .pending] {
            ac.addAction(UIAlertAction(title: status.rawValue, style: .default, handler: { [weak self] _ in
                self?.currentStatus = status
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
            case .approved: return req.status.lowercased() == "approved"
            }
        }

        let q = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let textFilter: ((RequestWithItem) -> Bool) = { req in
            guard !q.isEmpty else { return true }
            let title = req.items?.title.lowercased() ?? ""
            let id = req.item_id.lowercased()
            return title.contains(q) || id.contains(q)
        }

        visibleRequests = allRequests.filter { statusFilter($0) && textFilter($0) }
        updateEmptyStateIfNeeded()
        tableView.reloadData()
    }

    private func updateEmptyStateIfNeeded() {
        if visibleRequests.isEmpty {
            let container = UIStackView()
            container.axis = .vertical
            container.alignment = .center
            container.spacing = 10

            let icon = UIImageView(image: UIImage(systemName: "bag"))
            icon.tintColor = .secondaryLabel
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

            let title = UILabel()
            title.text = "No rentals yet"
            title.font = .systemFont(ofSize: 17, weight: .semibold)
            title.textColor = .label

            let subtitle = UILabel()
            subtitle.text = "Add your first item to start renting."
            subtitle.font = .systemFont(ofSize: 14)
            subtitle.textColor = .secondaryLabel

            let add = UIButton(type: .system)
            add.setTitle("Add Listing", for: .normal)
            add.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            add.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)

            container.addArrangedSubview(icon)
            container.addArrangedSubview(title)
            container.addArrangedSubview(subtitle)
            container.addArrangedSubview(add)

            let host = UIView()
            host.addSubview(container)
            container.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: host.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: host.centerYAnchor)
            ])

            tableView.backgroundView = host
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))
        }
    }

    private func presentError(_ message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func selectClause() -> String {
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """
    }

    private func orderClauseAscending() -> Bool { false }

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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Borrower", for: indexPath) as! BorrowerTableViewCell
        cell.configure(with: req, currencyFormatter: currencyFormatter)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        return cell
    }
}

// MARK: - UITableViewDelegate
extension MyRentalsViewController: UITableViewDelegate {
    // Keep your 125pt spacing between cards via section footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 125 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let nibName = "BookingApprovalViewController"
        let bookingVC: BookingApprovalViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: "BookingApprovalViewController", ofType: "xib") != nil {
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
