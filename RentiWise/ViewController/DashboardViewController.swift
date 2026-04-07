//
//  DashboardViewController.swift
//  RentiWise
//
//  Created by admin99 on 06/11/25.

import UIKit
import Supabase

class DashboardViewController: UIViewController, UITabBarDelegate {

    // MARK: - Outlets
    @IBOutlet weak var roleSegmented: UISegmentedControl!
    @IBOutlet weak var contentContainer: UIView!

    // MARK: - Actions
    @IBAction func Additem(_ sender: UIButton) {
        debugLog("[Dashboard] Additem tapped") // DEBUG
        Task { [weak self] in
            guard let self else { return }
            if await self.ensureAuthenticated(orOpen: .signUp) {
                debugLog("[Dashboard] Logged in, pushing AddItemFirst") // DEBUG
                let vc = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
                vc.title = "Add item"
                vc.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(vc, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
        }
    }

    // MARK: - Private UI
    private let tableView = UITableView(frame: .zero, style: .plain)

    private enum Segment: Int { case listing = 0, history = 1 }
    var initialSegment: Int?

    private var items: [Item] = []
    private struct HistoryRow { let title: String; let ratePerDay: Double; let borrowerName: String; let imagePath: String? }
    private var historyRows: [HistoryRow] = []

    // New: keep the full requests we fetched for history so we can open details
    private var ownerHistoryRequests: [RequestWithItem] = []
    private var displayedHistoryRequests: [RequestWithItem] = []

    // Loading state — shows skeleton placeholders while fetching
    private var isLoading: Bool = false {
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

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Listings"

        // Show the standard back button (navigates back to the previous screen)
        navigationItem.hidesBackButton = false

        setupNavigationFilterButton()
        setupTable()
        setupSegmentedControl()

        // Hide any storyboard buttons inside the content container (old ones)
        hideLegacyStoryboardButtonsIfAny()

        if let initial = initialSegment, initial >= 0, initial < roleSegmented.numberOfSegments {
            roleSegmented.selectedSegmentIndex = initial
        } else if roleSegmented.selectedSegmentIndex == UISegmentedControl.noSegment {
            roleSegmented.selectedSegmentIndex = Segment.listing.rawValue
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleItemsShouldRefresh), name: Notification.Name("itemsShouldRefresh"), object: nil)

        reloadForSelectedSegment()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didTapHome() {
        routeToHome()
    }

    private func routeToHome() {
        // 1. If there's a HomeViewController already in the nav stack, pop to it
        if let nav = navigationController {
            if let homeVC = nav.viewControllers.first(where: { $0 is HomeViewController }) {
                nav.popToViewController(homeVC, animated: true)
                return
            }
            // 2. Pop to root (root is usually HomeViewController)
            nav.popToRootViewController(animated: true)
            return
        }
        // 3. Switch to the Home tab if inside a tab bar
        if let tab = tabBarController {
            tab.selectedIndex = 0
            return
        }
        // 4. Last resort: dismiss
        dismiss(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: animated)

        // Create an explicit custom back button — tintColor on the item itself
        // is the most reliable way to control icon color regardless of appearance settings.
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        let chevron = UIImage(systemName: "chevron.left")
        let backBtn = UIBarButtonItem(image: chevron, style: .plain, target: self, action: #selector(backTapped))
        backBtn.tintColor = brandTeal
        navigationItem.leftBarButtonItem = backBtn
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    @objc private func handleItemsShouldRefresh() {
        guard Segment(rawValue: roleSegmented.selectedSegmentIndex) == .listing else { return }
        Task { await loadMyItems() }
    }

    // MARK: - Navigation bar button (Filter on right)
    private func setupNavigationFilterButton() {
        let symbol = UIImage(systemName: "line.3.horizontal.decrease.circle")
        let item = UIBarButtonItem(image: symbol, style: .plain, target: self, action: #selector(didTapNavFilter))
        item.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0) // brand teal
        navigationItem.rightBarButtonItem = item
        
        // Initial visibility
        updateFilterButtonVisibility()
    }

    private func updateFilterButtonVisibility() {
        let isHistorySegment = (roleSegmented.selectedSegmentIndex == Segment.history.rawValue)
        navigationItem.rightBarButtonItem?.isHidden = !isHistorySegment
        
        // Disabling it entirely is safer in some iOS versions if isHidden acts up on BarButtonItems
        if !isHistorySegment {
            navigationItem.rightBarButtonItem?.tintColor = .clear
            navigationItem.rightBarButtonItem?.isEnabled = false
        } else {
            navigationItem.rightBarButtonItem?.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }

    @objc private func didTapNavFilter() {
        presentFilterSheet()
    }

    private func presentFilterSheet() {
        let ac = UIAlertController(title: "Filter History", message: "Select a status to filter by", preferredStyle: .actionSheet)
        
        let inProgressAction = UIAlertAction(title: "In Progress", style: .default) { [weak self] _ in
            self?.activeHistoryFilter = .inProgress
            self?.applyHistoryFilter()
        }
        let completedAction = UIAlertAction(title: "Completed", style: .default) { [weak self] _ in
            self?.activeHistoryFilter = .completed
            self?.applyHistoryFilter()
        }
        let cancelledAction = UIAlertAction(title: "Cancelled", style: .default) { [weak self] _ in
            self?.activeHistoryFilter = .cancelled
            self?.applyHistoryFilter()
        }
        let allAction = UIAlertAction(title: "All", style: .default) { [weak self] _ in
            self?.activeHistoryFilter = .all
            self?.applyHistoryFilter()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        // Mark current filter
        switch activeHistoryFilter {
        case .inProgress: inProgressAction.setValue(true, forKey: "checked")
        case .completed: completedAction.setValue(true, forKey: "checked")
        case .cancelled: cancelledAction.setValue(true, forKey: "checked")
        case .all: allAction.setValue(true, forKey: "checked")
        }

        ac.addAction(allAction)
        ac.addAction(inProgressAction)
        ac.addAction(completedAction)
        ac.addAction(cancelledAction)
        ac.addAction(cancelAction)
        
        if let pop = ac.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(ac, animated: true)
    }

    enum HistoryFilter {
        case all, inProgress, completed, cancelled
    }
    private var activeHistoryFilter: HistoryFilter = .all

    private func applyHistoryFilter() {
        // We will re-run the mapping from ownerHistoryRequests to historyRows using the active filter.
        let filteredRequests: [RequestWithItem]
        
        switch activeHistoryFilter {
        case .inProgress:
            let inProgressStatuses: Set<String> = ["pending", "accepted", "approved", "active", "in_progress"]
            filteredRequests = ownerHistoryRequests.filter { inProgressStatuses.contains($0.status.lowercased()) }
        case .completed:
            let completedStatuses: Set<String> = ["completed", "returned"]
            filteredRequests = ownerHistoryRequests.filter { completedStatuses.contains($0.status.lowercased()) }
        case .cancelled:
            let cancelledStatuses: Set<String> = ["cancelled", "rejected", "denied"]
            filteredRequests = ownerHistoryRequests.filter { cancelledStatuses.contains($0.status.lowercased()) }
        case .all:
            filteredRequests = ownerHistoryRequests
        }

        displayedHistoryRequests = filteredRequests
        self.historyRows = filteredRequests.map { req in
            let title = req.items?.title ?? req.item_id
            let rate = req.items?.price_per_day ?? 0
            let borrowerOrStatus = req.status.capitalized
            let imagePath = req.items?.images.first
            return HistoryRow(title: title, ratePerDay: rate, borrowerName: borrowerOrStatus, imagePath: imagePath)
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if self.historyRows.isEmpty {
                self.loadEmptyStateIfNeeded()
            } else {
                self.tableView.backgroundView = nil
            }
        }
    }

    // MARK: - Setup
    private func setupSegmentedControl() {
        roleSegmented.addTarget(self, action: #selector(segmentedChanged(_:)), for: .valueChanged)
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        tableView.rowHeight = 130
        tableView.estimatedRowHeight = 130
        // Important: do not clip shadows
        tableView.clipsToBounds = false

        tableView.register(UINib(nibName: "LenderListingTableViewCell", bundle: nil), forCellReuseIdentifier: "Listing")
        tableView.register(UINib(nibName: "LenderHistoryTableViewCell", bundle: nil), forCellReuseIdentifier: "History")
        tableView.register(SkeletonTableViewCell.self, forCellReuseIdentifier: SkeletonTableViewCell.reuseID)

        contentContainer.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    // MARK: - Hide any legacy storyboard buttons in the container
    private func hideLegacyStoryboardButtonsIfAny() {
        // If there are any UIButton subviews in contentContainer, hide them so they don't interfere.
        for sub in contentContainer.subviews {
            if let button = sub as? UIButton {
                button.isHidden = true
                button.isUserInteractionEnabled = false
                debugLog("[Dashboard] Hiding legacy storyboard button: \(button)")
            }
        }
    }

    // MARK: - Segment handling
    @objc func roleChanged(_ sender: UISegmentedControl) { segmentedChanged(sender) }
    @objc private func segmentedChanged(_ sender: UISegmentedControl) { 
        updateFilterButtonVisibility()
        reloadForSelectedSegment() 
    }

    private func reloadForSelectedSegment() {
        updateFilterButtonVisibility()
        guard let segment = Segment(rawValue: roleSegmented.selectedSegmentIndex) else { return }
        switch segment {
        case .listing: Task { await loadMyItems() }
        case .history: Task { await loadOwnerHistoryFromDB() }
        }
    }

    // MARK: - Data loading
    private func loadEmptyStateIfNeeded() {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)

        if Segment(rawValue: roleSegmented.selectedSegmentIndex) == .listing {
            label.text = "Add item"
            tableView.backgroundView = items.isEmpty ? label : nil
        } else {
            label.text = "No History Yet"
            tableView.backgroundView = historyRows.isEmpty ? label : nil
        }
    }

    private func loadMyItems() async {
        await MainActor.run { self.isLoading = true }

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isLoading = false
                self.items = []
                self.loadEmptyStateIfNeeded()
            }
            return
        }

        do {
            let service = ItemsService()
            let allItems = try await service.fetchItems(category: "")
            let ownerItems = allItems
                .filter { $0.owner_id.lowercased() == userId.lowercased() }
                .sorted { ($0.created_at ?? Date.distantPast) > ($1.created_at ?? Date.distantPast) }
            let visibleItems = collapseAccidentalDuplicateListings(ownerItems)

            await MainActor.run {
                self.isLoading = false
                self.items = visibleItems
                self.tableView.reloadData()
                self.loadEmptyStateIfNeeded()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.items = []
                self.tableView.reloadData()
                self.loadEmptyStateIfNeeded()
            }
        }
    }

    private func collapseAccidentalDuplicateListings(_ source: [Item]) -> [Item] {
        var seenIds = Set<String>()
        var latestCreatedBySignature: [ListingDedupKey: Date] = [:]
        var deduped: [Item] = []

        for item in source {
            let normalizedId = item.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard seenIds.insert(normalizedId).inserted else { continue }

            let key = ListingDedupKey(item: item)
            let createdAt = item.created_at ?? .distantPast

            if let latestCreated = latestCreatedBySignature[key],
               abs(latestCreated.timeIntervalSince(createdAt)) <= 30 {
                continue
            }

            latestCreatedBySignature[key] = createdAt
            deduped.append(item)
        }

        return deduped
    }

    private func loadOwnerHistoryFromDB() async {
        await MainActor.run {
            self.isLoading = true
            self.historyRows = []
            self.ownerHistoryRequests = []
            self.displayedHistoryRequests = []
        }

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isLoading = false
                self.historyRows = []
                self.ownerHistoryRequests = []
                self.displayedHistoryRequests = []
                self.tableView.reloadData()
                self.loadEmptyStateIfNeeded()
            }
            return
        }

        // Mirror Home/Requests select and shape
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """

        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let requests = try JSONDecoder().decode([RequestWithItem].self, from: response.data)

            await MainActor.run {
                self.isLoading = false
                self.ownerHistoryRequests = requests
                self.applyHistoryFilter() // Replaces manual `mapped` logic and respects active filter
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.historyRows = []
                self.ownerHistoryRequests = []
                self.displayedHistoryRequests = []
                self.tableView.reloadData()
                self.loadEmptyStateIfNeeded()
            }
        }
    }
}

private struct ListingDedupKey: Hashable {
    let ownerId: String
    let title: String
    let category: String
    let condition: String
    let pricePerDayCents: Int
    let depositCents: Int
    let firstImagePath: String
    let isActive: Bool

    init(item: Item) {
        ownerId = item.owner_id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        title = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        condition = item.condition?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        pricePerDayCents = Int((item.price_per_day * 100).rounded())
        depositCents = Int((item.deposit_amount * 100).rounded())
        firstImagePath = item.images.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        isActive = item.is_active
    }
}

extension DashboardViewController: UITableViewDataSource {
    private static let skeletonCount = 4

    func numberOfSections(in tableView: UITableView) -> Int {
        if isLoading { return Self.skeletonCount }
        if Segment(rawValue: roleSegmented.selectedSegmentIndex) == .listing { return items.count }
        else { return historyRows.count }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Show skeleton placeholders while loading
        if isLoading {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SkeletonTableViewCell.reuseID, for: indexPath) as? SkeletonTableViewCell else {
                assertionFailure("Could not dequeue SkeletonTableViewCell")
                return UITableViewCell()
            }
            return cell
        }

        if Segment(rawValue: roleSegmented.selectedSegmentIndex) == .listing {
            guard indexPath.section < items.count else {
                return UITableViewCell()
            }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Listing", for: indexPath) as? LenderListingTableViewCell else {
                return UITableViewCell()
            }
            let item = items[indexPath.section]
            cell.configure(with: item, currencyFormatter: currencyFormatter)
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            return cell
        } else {
            guard indexPath.section < historyRows.count else {
                return UITableViewCell()
            }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "History", for: indexPath) as? LenderHistoryTableViewCell else {
                return UITableViewCell()
            }
            let row = historyRows[indexPath.section]
            cell.itemNameHistory?.text = row.title
            let amount = NSNumber(value: row.ratePerDay)
            let rateText = (currencyFormatter.string(from: amount) ?? "\(row.ratePerDay)") + " / day"
            cell.itemRateHistory?.text = rateText
            cell.itemBorrowerName?.text = row.borrowerName

            if let path = row.imagePath, let url = StorageURLBuilder.publicFileURL(for: path) {
                UIImageView.rw_loadImage(from: url) { [weak cell] image in
                    DispatchQueue.main.async {
                        cell?.itemImageHistory?.image = image
                        cell?.itemImageHistory?.contentMode = .scaleAspectFill
                        cell?.itemImageHistory?.clipsToBounds = true
                    }
                }
            } else {
                cell.itemImageHistory?.image = UIImage(systemName: "photo")
                cell.itemImageHistory?.tintColor = .secondaryLabel
                cell.itemImageHistory?.contentMode = .scaleAspectFit
            }
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            return cell
        }
    }
}

extension DashboardViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 16 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard !isLoading else { return }
        guard let segment = Segment(rawValue: roleSegmented.selectedSegmentIndex) else { return }

        switch segment {
        case .listing:
            // Open own item detail with 3-dots menu (Edit/Delete)
            guard indexPath.section < items.count else { return }
            let item = items[indexPath.section]

            let nibName = "ProductViewController"
            let productVC: ProductViewController
            if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                productVC = ProductViewController(nibName: nibName, bundle: nil)
            } else {
                productVC = ProductViewController()
            }
            productVC.configure(with: item)
            productVC.displayMode = .ownItem
            productVC.title = "Product Detail"
            productVC.hidesBottomBarWhenPushed = true

            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(productVC, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: productVC)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            }

        case .history:
            // New: open BookingApprovalViewController in history mode
            guard indexPath.section < displayedHistoryRequests.count else { return }
            let req = displayedHistoryRequests[indexPath.section]

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
            bookingVC.mode = .history
            bookingVC.request = req

            if let tab = self.tabBarController {
                tab.tabBar.isHidden = true
            }

            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(bookingVC, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: bookingVC)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            }
        }
    }
}
