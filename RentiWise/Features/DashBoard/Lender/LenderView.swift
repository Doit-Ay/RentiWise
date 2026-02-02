// LenderView
import UIKit
import Supabase

protocol LenderViewDelegate: AnyObject {
    // Called when the inner segmented control changes
    func lenderView(_ lenderView: LenderView, didSelectInnerIndex index: Int)
    // Called when the Add button is tapped
    func lenderViewDidTapAddButton(_ lenderView: LenderView)
    func lenderViewDidTapEarnings(_ lenderView: LenderView)
    func lenderView(_ lenderView: LenderView, didSelectRequestAt index: Int)
    // New: called when a Listing item (segment 0) is tapped
    func lenderView(_ lenderView: LenderView, didSelectItem item: Item)
}

final class LenderView: UIView {

    // Connect this to the top-level view in LenderView.xib (File’s Owner -> view)
    @IBOutlet private(set) var view: UIView!
    @IBOutlet private weak var innerSegmented: UISegmentedControl!
    @IBOutlet private weak var earningLabel: UILabel!

    @IBOutlet weak var earningsView: UIView!
    // You replaced the container with a table view
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: LenderViewDelegate?

    // MARK: - Data/state
    private var selectedInnerIndex: Int = 0 {
        didSet {
            reloadForSelectedSegment()
            delegate?.lenderView(self, didSelectInnerIndex: selectedInnerIndex)
        }
    }

    // Listing data (segment 0)
    private var myItems: [Item] = []

    // Request data (segment 1) – Variant 1 with items join only
    // IMPORTANT: RequestWithItem and ItemLite are defined ONCE in DashboardLenderRequestViewController.swift
    private var myRequests: [RequestWithItem] = []

    // History data (segment 2)
    private var myHistory: [HistoryRow] = []

    // Format like in CategoriesViewController
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Prevent double-adding if somehow called twice
        if view != nil, view.isDescendant(of: self) {
            return
        }

        // Load the nib with File’s Owner pattern
        Bundle.main.loadNibNamed("LenderView", owner: self, options: nil)

        // Ensure the 'view' outlet is connected to the top-level view in the XIB
        guard let content = view else {
            assertionFailure("LenderView.xib not loaded or 'view' outlet not connected to top-level view. Check: File's Owner = LenderView, top view = UIView, and connect File's Owner 'view' -> top view.")
            return
        }

        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)

        // Segmented default
        if innerSegmented.numberOfSegments > 0 {
            if innerSegmented.selectedSegmentIndex == UISegmentedControl.noSegment {
                innerSegmented.selectedSegmentIndex = 0
            }
        }
        selectedInnerIndex = innerSegmented.selectedSegmentIndex

        // Accessibility
        innerSegmented?.accessibilityLabel = "Lender Sections"
        earningLabel?.accessibilityLabel = "Earnings"

        // Table setup
        setupTable()

        // Earnings tap
        let earningsTap = UITapGestureRecognizer(target: self, action: #selector(didTapEarnings))
        earningsView?.isUserInteractionEnabled = true
        earningsView?.addGestureRecognizer(earningsTap)
        earningsView?.accessibilityTraits = .button
        earningsView?.isAccessibilityElement = true
        earningsView?.accessibilityLabel = "Earnings overview"

        // Listen for refresh notifications after Accept/Deny
        NotificationCenter.default.addObserver(self, selector: #selector(handleRequestsShouldRefresh), name: Notification.Name("requestsShouldRefresh"), object: nil)

        // Initial load for the current segment
        reloadForSelectedSegment()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Table setup
    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self

        // Visuals and row height
        tableView.rowHeight = 140
        tableView.estimatedRowHeight = 140
        tableView.separatorStyle = .none
        tableView.backgroundColor = .secondarySystemBackground
        tableView.contentInsetAdjustmentBehavior = .always
        // Important: do not clip shadows from cells’ internal cards
        tableView.clipsToBounds = false

        // Register your cell nibs
        tableView.register(UINib(nibName: "LenderListingTableViewCell", bundle: nil), forCellReuseIdentifier: "Listing")
        tableView.register(UINib(nibName: "LenderRequestTableViewCell", bundle: nil), forCellReuseIdentifier: "Request")
        tableView.register(UINib(nibName: "LenderHistoryTableViewCell", bundle: nil), forCellReuseIdentifier: "History")
    }

    // MARK: - Actions wired in the XIB
    @IBAction func Additem(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.lenderViewDidTapAddButton(self)
    }

    @IBAction func innerSegmentChanged(_ sender: UISegmentedControl) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedInnerIndex = sender.selectedSegmentIndex
    }

    @objc private func didTapEarnings() {
        UISelectionFeedbackGenerator().selectionChanged()
        delegate?.lenderViewDidTapEarnings(self)
    }

    // MARK: - Segment handling
    private func reloadForSelectedSegment() {
        switch selectedInnerIndex {
        case 0:
            Task { await loadMyItems() }
        case 1:
            Task { await loadMyRequests() }
        case 2:
            Task {
                await loadHistoryFromDB()
                await MainActor.run {
                    self.tableView.reloadData()
                    self.updateEmptyStateIfNeeded()
                }
            }
        default:
            break
        }
    }

    private func updateEmptyStateIfNeeded() {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)

        var show = false
        switch selectedInnerIndex {
        case 0:
            show = myItems.isEmpty
            label.text = "Add item"
        case 1:
            show = myRequests.isEmpty
            label.text = "No Request till Now"
        case 2:
            show = myHistory.isEmpty
            label.text = "No History"
        default:
            show = false
        }

        tableView.backgroundView = show ? label : nil
    }

    // MARK: - Data loading (Listing)
    private func loadMyItems() async {
        // Get current user
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.myItems = []
                self.tableView.reloadData()
                self.updateEmptyStateIfNeeded()
            }
            return
        }

        do {
            // Fetch only this owner's items; newest first
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select()
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([Item].self, from: response.data)

            await MainActor.run {
                self.myItems = items
                self.tableView.reloadData()
                self.updateEmptyStateIfNeeded()
            }
        } catch {
            await MainActor.run {
                self.myItems = []
                self.tableView.reloadData()
                self.updateEmptyStateIfNeeded()
            }
        }
    }

    // MARK: - Data loading (Requests + items only)
    private func loadMyRequests() async {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.myRequests = []
                self.tableView.reloadData()
                self.updateEmptyStateIfNeeded()
            }
            return
        }

        // Base fields + items(...) via FK requests_item_id_fkey
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day,category)
        """

        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let rows = try JSONDecoder().decode([RequestWithItem].self, from: response.data)

            await MainActor.run {
                self.myRequests = rows
                self.tableView.reloadData()
                self.updateEmptyStateIfNeeded()
            }
        } catch {
            // If join fails due to RLS or missing FK inference, fall back to base select so the list still shows.
            do {
                let response = try await SupabaseManager.shared.client
                    .from("requests")
                    .select("id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at")
                    .eq("owner_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()

                // Decode base without items
                let baseRows = try JSONDecoder().decode([RequestBase].self, from: response.data)
                await MainActor.run {
                    // Map base → RequestWithItem (items: nil)
                    self.myRequests = baseRows.map { base in
                        RequestWithItem(
                            id: base.id,
                            item_id: base.item_id,
                            owner_id: base.owner_id,
                            borrower_id: base.borrower_id,
                            start_date: base.start_date,
                            end_date: base.end_date,
                            pickup_time: base.pickup_time,
                            status: base.status,
                            created_at: base.created_at,
                            items: nil
                        )
                    }
                    self.tableView.reloadData()
                    self.updateEmptyStateIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.myRequests = []
                    self.tableView.reloadData()
                    self.updateEmptyStateIfNeeded()
                }
            }
        }
    }

    // MARK: - Public helpers used by DashboardViewController
    func request(at index: Int) -> RequestWithItem? {
        guard index >= 0 && index < myRequests.count else { return nil }
        return myRequests[index]
    }

    func refreshRequests() {
        selectedInnerIndex = 1
        Task { await loadMyRequests() }
    }

    @objc private func handleRequestsShouldRefresh() {
        refreshRequests()
    }

    // MARK: - History from database (rentals_history) showing same item details as Requests
    private func loadHistoryFromDB() async {
        await MainActor.run { self.myHistory = [] }

        guard let userId = await SupabaseManager.shared.currentUserId() else { return }

        // Join items and borrower display name (optional)
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,total_amount,created_at,
        items(title,images,price_per_day),
        user_profiles!rentals_history_borrower_id_fkey(full_name)
        """

        struct ItemJoin: Decodable {
            let title: String?
            let images: [String]?
            let price_per_day: Double?
        }
        struct BorrowerProfile: Decodable {
            let full_name: String?
        }
        struct HistoryDecodable: Decodable {
            let id: String
            let item_id: String
            let owner_id: String
            let borrower_id: String
            let start_date: String
            let end_date: String
            let total_amount: Double?
            let created_at: String?
            let items: ItemJoin?
            let user_profiles: BorrowerProfile?
        }

        do {
            let resp = try await SupabaseManager.shared.client
                .from("rentals_history")
                .select(select)
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            let rows = try decoder.decode([HistoryDecodable].self, from: resp.data)

            let mapped: [HistoryRow] = rows.map { r in
                let title = r.items?.title ?? r.item_id
                let rate = r.items?.price_per_day ?? 0
                let borrower = (r.user_profiles?.full_name?.isEmpty == false) ? "To: \(r.user_profiles!.full_name!)" : "To: —"
                let imagePath = r.items?.images?.first
                return HistoryRow(title: title, ratePerDay: rate, borrowerName: borrower, imagePath: imagePath)
            }

            await MainActor.run {
                self.myHistory = mapped
            }
        } catch {
            // Keep empty on error
            await MainActor.run { self.myHistory = [] }
        }
    }
}

// MARK: - Models for Variant 1 (only RequestBase lives here for fallback)
private struct RequestBase: Decodable {
    let id: String
    let item_id: String
    let owner_id: String
    let borrower_id: String
    let start_date: String
    let end_date: String
    let pickup_time: String?
    let status: String
    let created_at: String?
}

// History model used for the table
private struct HistoryRow {
    let id: String = UUID().uuidString
    let title: String
    let ratePerDay: Double
    let borrowerName: String
    let imagePath: String? // optional storage path if you later want to show images
}

// MARK: - UITableViewDataSource
extension LenderView: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        switch selectedInnerIndex {
        case 0: return myItems.count
        case 1: return myRequests.count
        case 2: return myHistory.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // One card per section so we can add inter-card spacing via footers
        return 1
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedInnerIndex {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Listing", for: indexPath) as? LenderListingTableViewCell else {
                return UITableViewCell()
            }
            let item = myItems[indexPath.section]
            cell.configure(with: item, currencyFormatter: currencyFormatter)
            // Important: keep clear so the internal glass card shows its shadow
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Request", for: indexPath) as! LenderRequestTableViewCell
            let req = myRequests[indexPath.section]

            // Name: prefer item title, fallback to item_id
            let title = req.items?.title ?? req.item_id
            cell.itemNameRequest.text = title
            cell.itemNameRequest.numberOfLines = 1
            cell.itemNameRequest.lineBreakMode = .byTruncatingTail

            // Rate: from items.price_per_day if available; else show date range
            if let p = req.items?.price_per_day {
                let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
                cell.itemRateRequest.text = text
            } else {
                let sql = DateFormatter()
                sql.calendar = Calendar(identifier: .gregorian)
                sql.timeZone = TimeZone(secondsFromGMT: 0)
                sql.dateFormat = "yyyy-MM-dd"
                let display = DateFormatter()
                display.calendar = Calendar(identifier: .gregorian)
                display.timeZone = .current
                display.dateFormat = "d MMM yyyy"
                if let s = sql.date(from: req.start_date),
                   let e = sql.date(from: req.end_date) {
                    cell.itemRateRequest.text = "\(display.string(from: s)) — \(display.string(from: e))"
                } else {
                    cell.itemRateRequest.text = "—"
                }
            }

            // Borrower label: keep status for now (you can change to "From: ..." later)
            cell.itemBorrowerRequest.text = req.status.capitalized

            // Image: first item image if any
            if let path = req.items?.images.first,
               let url = StorageURLBuilder.publicFileURL(for: path) {
                cell.setImage(from: url)
            } else {
                cell.itemImageRequest.image = UIImage(systemName: "photo")
                cell.itemImageRequest.tintColor = .secondaryLabel
                cell.itemImageRequest.contentMode = .scaleAspectFit
            }

            cell.backgroundColor = .secondarySystemBackground
            cell.contentView.backgroundColor = .secondarySystemBackground
            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "History", for: indexPath) as! LenderHistoryTableViewCell
            let row = myHistory[indexPath.section]

            // Title
            cell.itemNameHistory?.text = row.title

            // Rate
            let amount = NSNumber(value: row.ratePerDay)
            let rateText = (currencyFormatter.string(from: amount) ?? "\(row.ratePerDay)") + " / day"
            cell.itemRateHistory?.text = rateText

            // Borrower label
            cell.itemBorrowerName?.text = row.borrowerName

            // Image: if you later set imagePath with a public storage path, load it; else show placeholder
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

            cell.backgroundColor = .secondarySystemBackground
            cell.contentView.backgroundColor = .secondarySystemBackground
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate
extension LenderView: UITableViewDelegate {
    // Spacing between cards using section footers
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch selectedInnerIndex {
        case 0, 1, 2:
            return 10
        default:
            return 0.001
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch selectedInnerIndex {
        case 0:
            // Listing: open product view in own-item mode via delegate
            let item = myItems[indexPath.section]
            delegate?.lenderView(self, didSelectItem: item)
        case 1:
            // Request section selection
            delegate?.lenderView(self, didSelectRequestAt: indexPath.section)
        default:
            break
        }
    }
}
