//  MyRentalsViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/12/25.
//

import UIKit
import Supabase

final class MyRentalsViewController: UIViewController {

    // Cache NIB availability once at class load — avoids a disk read on every cell tap
    private static let bookingApprovalNibName: String = {
        let name = "BookingApprovalViewController"
        return (Bundle.main.path(forResource: name, ofType: "nib") != nil ||
                Bundle.main.path(forResource: name, ofType: "xib") != nil) ? name : ""
    }()

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refresh = UIRefreshControl()

    // UI elements
    private let searchBarContainer = UIView()
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
        case accepted = "Accepted"
        case pending = "Pending"
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

    // MARK: - Tab bar visibility management (for UI-hosted path)
    private var didHideTabBarManually = false

    // Prevents double-push; cleared in viewDidAppear after the push completes.
    private var isNavigating = false

    // Loading state — shows skeleton placeholders while fetching
    private var isLoading = false {
        didSet {
            tableView.reloadData()
            if isLoading { tableView.backgroundView = nil }
        }
    }

    // MARK: - Cancel request observer
    private var cancelObserver: NSObjectProtocol?

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

        // Set up filter button in navigation bar
        setupNavigationBar()
        
        // Set up search bar below navigation bar
        setupSearchBar()
        setupTable()

        // Listen for cancel request notifications (registered once, lives for VC lifetime)
        cancelObserver = NotificationCenter.default.addObserver(
            forName: BookingApprovalViewController.requestCancelledNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRequestCancelled(notification)
        }

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

        ensureTabBarHiddenIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Allow tapping another item now that the push/pop transition is done.
        isNavigating = false
    }

    deinit {
        if let token = cancelObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Cancel request handler
    private func handleRequestCancelled(_ notification: Notification) {
        guard let requestId = notification.userInfo?["requestId"] as? String else { return }

        // Update in allRequests
        if let index = allRequests.firstIndex(where: { $0.id == requestId }) {
            var updatedRequest = allRequests[index]
            updatedRequest.status = "cancelled"
            allRequests[index] = updatedRequest
        }

        // Update in visibleRequests and reload section
        if let sectionIndex = visibleRequests.firstIndex(where: { $0.id == requestId }) {
            var updatedVisibleRequest = visibleRequests[sectionIndex]
            updatedVisibleRequest.status = "cancelled"
            visibleRequests[sectionIndex] = updatedVisibleRequest
            
            tableView.reloadSections(IndexSet(integer: sectionIndex), with: .automatic)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore tab bar only if we hid it here
        restoreTabBarIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Table extends below safe area, but add bottom inset so content can scroll above home indicator
        let bottomSafeArea = view.safeAreaInsets.bottom
        tableView.contentInset.bottom = bottomSafeArea
        tableView.verticalScrollIndicatorInsets.bottom = bottomSafeArea
    }

    // MARK: - UI Setup
    private func setupNavigationBar() {
        // Keep title as "My Rentals"
        title = "My Rentals"
        
        // Configure filter button for navigation bar
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        filterButton.tintColor = .label
        filterButton.addTarget(self, action: #selector(didTapFilter), for: .touchUpInside)
        filterButton.accessibilityLabel = "Filter rentals"
        
        // Set filter button as right bar button item
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: filterButton)
    }
    
    private func setupSearchBar() {
        // Container for search bar
        searchBarContainer.translatesAutoresizingMaskIntoConstraints = false
        searchBarContainer.backgroundColor = .systemGroupedBackground
        view.addSubview(searchBarContainer)
        
        // Configure search bar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search rentals"
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        
        // Apply consistent RentiWise styling
        searchBar.applyRentiWiseStyle()
        
        searchBarContainer.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            // Container constraints
            searchBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Search bar constraints
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor, constant: -16),
            searchBar.centerYAnchor.constraint(equalTo: searchBarContainer.centerYAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Apply rounded corners after layout
        DispatchQueue.main.async { [weak self] in
            self?.searchBar.applyRoundedCorners()
        }
    }

    
    private func setupTable() {
        // Set up table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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
        tableView.register(SkeletonTableViewCell.self, forCellReuseIdentifier: SkeletonTableViewCell.reuseID)

        tableView.dataSource = self
        tableView.delegate = self

        // Let content extend to bottom; manage insets manually
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }

        // Add top padding so items don't appear under search bar
        tableView.contentInset = UIEdgeInsets(top: 70, left: 0, bottom: 0, right: 0)
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 70, left: 0, bottom: 0, right: 0)

        // Explicitly zero any extra controller safe-area bottom inset
        self.additionalSafeAreaInsets.bottom = 0

        refresh.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh

        tableView.tableFooterView = UIView(frame: .zero)
    }

    // MARK: - Actions

    @objc private func didTapFilter() {
        let ac = UIAlertController(title: "Filter rentals", message: nil, preferredStyle: .actionSheet)
        // Present in order: All, Accepted, Pending
        for status in [StatusFilter.all, .accepted, .pending] {
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
            case .accepted:
                // Treat either "accepted" or "approved" as Accepted
                let s = req.status.lowercased()
                return s == "accepted" || s == "approved"
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
            subtitle.text = "Your rental bookings will appear here."
            subtitle.font = .systemFont(ofSize: 14)
            subtitle.textColor = .secondaryLabel

            container.addArrangedSubview(icon)
            container.addArrangedSubview(title)
            container.addArrangedSubview(subtitle)

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
            // Restore filter button
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: filterButton)
        }
    }

    private func selectClause() -> String {
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """
    }

    private func orderClauseAscending() -> Bool { false }

    private func loadData(showSpinner: Bool) async {
        if showSpinner {
            showLoadingInNav(true)
            isLoading = true
        }
        defer {
            Task { @MainActor in
                self.showLoadingInNav(false)
                self.refresh.endRefreshing()
                self.isLoading = false
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

    // MARK: - Simple alert helper (fix for missing presentError)
    private func presentError(_ message: String) {
        let a = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - Tab bar visibility helpers
    private func ensureTabBarHiddenIfNeeded() {
        guard let tab = findTabBarController() else { return }
        if !tab.tabBar.isHidden {
            tab.tabBar.isHidden = true
            didHideTabBarManually = true
        }
    }

    private func restoreTabBarIfNeeded() {
        guard didHideTabBarManually, let tab = findTabBarController() else { return }
        tab.tabBar.isHidden = false
        didHideTabBarManually = false
    }

    private func findTabBarController() -> UITabBarController? {
        var parentVC: UIViewController? = self
        while let current = parentVC {
            if let tab = current as? UITabBarController { return tab }
            if let tab = current.tabBarController { return tab }
            parentVC = current.parent ?? current.presentingViewController ?? current.navigationController
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let tab = window.rootViewController as? UITabBarController {
            return tab
        }
        return nil
    }
}

// MARK: - UITableViewDataSource
extension MyRentalsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        isLoading ? 4 : visibleRequests.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            return tableView.dequeueReusableCell(withIdentifier: SkeletonTableViewCell.reuseID, for: indexPath) as! SkeletonTableViewCell
        }
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
    // Spacing between cards reduced to 16pt instead of massive 125pt
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 125 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isNavigating, !isLoading else { return }

        isNavigating = true
        tableView.deselectRow(at: indexPath, animated: true)

        // Instantiate using cached NIB name (no disk read on every tap)
        let nibName = Self.bookingApprovalNibName
        let bookingVC: BookingApprovalViewController = nibName.isEmpty
            ? BookingApprovalViewController()
            : BookingApprovalViewController(nibName: nibName, bundle: nil)

        bookingVC.title = "Booking Approval"
        bookingVC.hidesBottomBarWhenPushed = true

        let selected = visibleRequests[indexPath.section]
        bookingVC.request = selected

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
