// LenderView
import UIKit
import Supabase

protocol LenderViewDelegate: AnyObject {
    // Called when the inner segmented control changes
    func lenderView(_ lenderView: LenderView, didSelectInnerIndex index: Int)
    // Called when the Add button is tapped
    func lenderViewDidTapAddButton(_ lenderView: LenderView)
}

final class LenderView: UIView {

    // Connect this to the top-level view in LenderView.xib (File’s Owner -> view)
    @IBOutlet private(set) var view: UIView!
    @IBOutlet private weak var innerSegmented: UISegmentedControl!
    @IBOutlet private weak var earningLabel: UILabel!

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

    // Request data (segment 1) – placeholder model for now
    private var myRequests: [RequestRow] = []

    // History data (segment 2) – placeholder model for now
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

        // Initial load for the current segment
        reloadForSelectedSegment()
    }

    // MARK: - Table setup
    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self

        // Visuals and row height
        tableView.rowHeight = 140
        tableView.estimatedRowHeight = 140
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.contentInsetAdjustmentBehavior = .always

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

    // MARK: - Segment handling
    private func reloadForSelectedSegment() {
        switch selectedInnerIndex {
        case 0:
            Task { await loadMyItems() }
        case 1:
            // For now we don’t have a backend; clear and show empty state
            myRequests = []
            tableView.reloadData()
            updateEmptyStateIfNeeded()
        case 2:
            // For now we don’t have a backend; clear and show empty state
            myHistory = []
            tableView.reloadData()
            updateEmptyStateIfNeeded()
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
}

// Temporary placeholder models for Request and History until DB exists
private struct RequestRow {
    let id: String = UUID().uuidString
}
private struct HistoryRow {
    let id: String = UUID().uuidString
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
            return cell

        case 1:
            // Configure your request cell here when you have a model
            let cell = tableView.dequeueReusableCell(withIdentifier: "Request", for: indexPath) as! LenderRequestTableViewCell
            // TODO: cell.configure(with: myRequests[indexPath.section])
            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "History", for: indexPath) as! LenderHistoryTableViewCell
            // TODO: cell.configure(with: myHistory[indexPath.section])
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
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
