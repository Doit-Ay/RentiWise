//
//  DashboardLenderRequestViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit
import Supabase

class DashboardLenderRequestViewController: UIViewController {

    // Inject this before pushing
    var request: RequestWithItem? {
        didSet {
            // If the view is loaded, apply immediately on main thread
            if isViewLoaded {
                DispatchQueue.main.async { [weak self] in
                    self?.applyRequestToUI()
                }
            }
        }
    }

    @IBOutlet weak var bluecard: UIView!
    @IBOutlet weak var whitecard: UIView!
    @IBOutlet weak var prodimage: UIImageView!
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var Bookingcard: UIView!
    @IBOutlet weak var datelabel: UILabel!
    @IBOutlet weak var numberodDaysLabel: UILabel!
    @IBOutlet weak var pickuptimeLabel: UILabel!
    @IBOutlet weak var ownCard: UIView!
    @IBOutlet weak var initial: UIImageView!
    @IBOutlet weak var ownNameLabel: UILabel!
    @IBOutlet weak var ownRatingLabel: UILabel!
    @IBOutlet weak var ownDistLabel: UILabel!
    @IBOutlet weak var priceCard: UIView!
    @IBOutlet weak var feerentLabel: UILabel!
    @IBOutlet weak var secRateLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!

    // Buttons
    @IBOutlet weak var acceptButton: UIButton!   // CONNECT THIS IN IB
    @IBOutlet weak var denyButton: UIButton!
    @IBOutlet weak var denybutton: UIButton!     // if this is a duplicate, keep it connected; else you can remove it

    // Cache fetched deposit so we don’t refetch repeatedly
    private var depositAmount: Double?

    // Programmatic status row (shown when status != pending)
    private var statusRowContainer: UIStackView?
    private var statusValueLabel: UILabel?
    private var changeStatusButton: UIButton?      // the single "Deny" or "Accept" action button
    private var changeWindowMessageLabel: UILabel? // "You can change within 24 h or before payment"

    // White background bar behind the status row
    private var statusBackgroundView: UIView?
    private var statusBackgroundBottomConstraint: NSLayoutConstraint?

    /// Timestamp when the most recent accept/deny decision was made.
    /// Used to enforce the 24-hour change window on the client side.
    private var decisionTimestamp: Date?

    private let displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone.current
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    private let sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Parse pickup_time saved as "HH:mm:ssXXXXX" (e.g., "13:40:00+05:30")
    private lazy var sqlTimeParser: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "HH:mm:ssXXXXX"
        return df
    }()

    // Display localized short time like "1:40 PM"
    private lazy var displayTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Details"

        // Style deny button border color to #5DA9B6
        denyButton?.layer.borderWidth = 1
        denyButton?.layer.cornerRadius = 12
        denyButton?.layer.masksToBounds = true
        denyButton?.layer.borderColor = UIColor(hex: "5DA9B6").cgColor

        // Basic defaults
        prodimage?.image = UIImage(systemName: "photo")
        prodimage?.tintColor = .secondaryLabel
        prodimage?.contentMode = .scaleAspectFit

        // Prepare status row (hidden by default) and its background
        ensureStatusRow()

        applyRequestToUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the status background above other content
        if let bg = statusBackgroundView {
            view.bringSubviewToFront(bg)
        }
    }

    private func ensureStatusRow() {
        guard statusRowContainer == nil else { return }

        // ── Message line ────────────────────────────────────────────────
        let messageLabel = UILabel()
        messageLabel.font = .systemFont(ofSize: 12, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.text = "You can change your decision within 24 hours or before the borrower makes the payment."

        // ── Status label ─────────────────────────────────────────────────
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label

        // ── Single opposite-action button ─────────────────────────────────
        let change = UIButton(type: .system)
        change.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        change.addTarget(self, action: #selector(didTapChangeStatus), for: .touchUpInside)
        change.layer.cornerRadius = 12
        change.layer.borderWidth = 1.5
        change.layer.borderColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0).cgColor
        change.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        change.setContentHuggingPriority(.required, for: .horizontal)

        // Horizontal row: [ status label ] [ spacer ] [ change button ]
        let row = UIStackView(arrangedSubviews: [label, UIView(), change])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        // Vertical stack: message on top, then the status row
        let stack = UIStackView(arrangedSubviews: [messageLabel, row])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Background bar pinned to bottom
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = .systemBackground
        bg.layer.shadowColor = UIColor.black.cgColor
        bg.layer.shadowOpacity = 0.08
        bg.layer.shadowRadius = 8
        bg.layer.shadowOffset = CGSize(width: 0, height: -3)
        if #available(iOS 11.0, *) {
            bg.layer.cornerRadius = 16
            bg.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bg.layer.masksToBounds = false // shadows need false
        }

        let host = view!
        host.addSubview(bg)
        bg.addSubview(stack)

        let bottom = bg.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottom,
            bg.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: bg.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bg.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        host.bringSubviewToFront(bg)
        bg.isHidden = true
        stack.isHidden = true

        statusRowContainer    = stack
        statusValueLabel      = label
        changeStatusButton    = change
        changeWindowMessageLabel = messageLabel
        statusBackgroundView  = bg
        statusBackgroundBottomConstraint = bottom
    }

    private func applyRequestToUI() {
        guard let req = request else {
            itemNameLabel?.text = ""
            categoryLabel?.text = ""
            datelabel?.text = ""
            numberodDaysLabel?.text = ""
            pickuptimeLabel?.text = ""
            ownNameLabel?.text = ""
            ownRatingLabel?.text = ""
            ownDistLabel?.text = ""
            feerentLabel?.text = ""
            secRateLabel?.text = ""
            totalLabel?.text = ""
            updateButtonsAndStatusUI(status: nil)
            return
        }

        // Restore persisted decision timestamp so the 24h window is enforced after app restart
        if decisionTimestamp == nil {
            decisionTimestamp = loadDecisionTimestamp(requestId: req.id)
        }

        // Title from joined item, fallback to item_id
        itemNameLabel?.text = req.items?.title ?? req.item_id

        // Category from joined item if available
        if let cat = req.items?.category, !cat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            categoryLabel?.text = cat
        } else {
            categoryLabel?.text = "—"
            // Fallback: fetch category directly if missing in the injected request
            Task { [weak self] in
                guard let self = self else { return }
                if let fresh = await self.fetchItemCategory(itemId: req.item_id) {
                    await MainActor.run {
                        self.categoryLabel?.text = fresh
                    }
                }
            }
        }

        // Dates and duration
        let startDate = sqlDateFormatter.date(from: req.start_date)
        let endDate = sqlDateFormatter.date(from: req.end_date)

        var days: Int?
        if let s = startDate, let e = endDate {
            datelabel?.text = "\(displayDateFormatter.string(from: s)) — \(displayDateFormatter.string(from: e))"
            let d = max(1, Int(ceil(e.timeIntervalSince(s) / 86400.0)))
            days = d
            numberodDaysLabel?.text = "\(d) day\(d == 1 ? "" : "s")"
        } else {
            datelabel?.text = "—"
            numberodDaysLabel?.text = "—"
        }

        // Pickup time: parse "HH:mm:ssXXXXX" and show localized short time
        if let raw = req.pickup_time, !raw.isEmpty {
            if let date = sqlTimeParser.date(from: raw) {
                pickuptimeLabel?.text = displayTimeFormatter.string(from: date)
            } else {
                // Fallbacks for possible older formats like "HH:mm" or "HH:mm:ss"
                let fallbacks = ["HH:mm:ss", "HH:mm"]
                var shown = false
                for fmt in fallbacks {
                    let df = DateFormatter()
                    df.calendar = Calendar(identifier: .gregorian)
                    df.timeZone = .current
                    df.dateFormat = fmt
                    if let d = df.date(from: raw) {
                        pickuptimeLabel?.text = displayTimeFormatter.string(from: d)
                        shown = true
                        break
                    }
                }
                if !shown {
                    // Last resort: show raw
                    pickuptimeLabel?.text = raw
                }
            }
        } else {
            pickuptimeLabel?.text = "—"
        }

        // Price per day from joined item
        if let p = req.items?.price_per_day {
            let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
            feerentLabel?.text = text
        } else {
            feerentLabel?.text = ""
        }

        // Owner name: fetch from users, fallback to profiles
        resolveOwnerName(for: req.owner_id)

        // Image from joined item
        if let path = req.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    self?.prodimage?.image = img
                    self?.prodimage?.contentMode = .scaleAspectFill
                    self?.prodimage?.clipsToBounds = true
                }
            }
        } else {
            prodimage?.image = UIImage(systemName: "photo")
            prodimage?.tintColor = .secondaryLabel
            self.prodimage?.contentMode = .scaleAspectFit
        }

        // Owner placeholders (ratings/distance can be refined later)
        if ownRatingLabel?.text?.isEmpty ?? true { ownRatingLabel?.text = "★ 4.7" }

        // Distance: compute via DistanceService using a lightweight Item built from the request
        ownDistLabel?.text = "..."
        Task { [weak self] in
            guard let self = self, let req = self.request else { return }
            let shim = self.makeShimItem(from: req)
            let text = await DistanceService.shared.distanceText(for: shim)
            await MainActor.run {
                self.ownDistLabel?.text = text
            }
        }

        // Pricing: need deposit_amount from items; fetch if we don’t have it yet
        computeAndDisplayTotals(days: days, pricePerDay: req.items?.price_per_day, itemId: req.item_id)

        // Buttons vs status row
        updateButtonsAndStatusUI(status: req.status)
    }

    private func updateButtonsAndStatusUI(status: String?) {
        let current = (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isPending = current.isEmpty || current == "pending"
        let isPaid    = current == "paid"

        // Accept/Deny buttons visible only while pending
        acceptButton?.isHidden  = !isPending
        denyButton?.isHidden    = !isPending
        denybutton?.isHidden    = !isPending

        // Status bar visible when decision has been made
        let showBar = !isPending
        statusRowContainer?.isHidden    = !showBar
        statusBackgroundView?.isHidden  = !showBar

        guard showBar else { return }

        // Status label
        let display = current.capitalized.isEmpty ? "—" : current.capitalized
        statusValueLabel?.text = "Status: \(display)"

        // Determine if the change window is still open:
        //   • within 24 h of the decision, AND
        //   • request has NOT been paid
        let windowOpen = isWithinChangeWindow() && !isPaid

        // Show the OPPOSITE action button only while the window is open
        changeStatusButton?.isHidden = !windowOpen
        changeWindowMessageLabel?.isHidden = !windowOpen

        if windowOpen {
            switch current {
            case "accepted":
                // Accepted → offer Deny
                changeStatusButton?.setTitle("Deny", for: .normal)
                changeStatusButton?.tintColor = UIColor(red: 0xE5/255.0, green: 0x53/255.0, blue: 0x3A/255.0, alpha: 1.0)
                changeStatusButton?.layer.borderColor = UIColor(red: 0xE5/255.0, green: 0x53/255.0, blue: 0x3A/255.0, alpha: 1.0).cgColor
            case "denied":
                // Denied → offer Accept
                changeStatusButton?.setTitle("Accept", for: .normal)
                changeStatusButton?.tintColor = UIColor(red: 0x34/255.0, green: 0xAA/255.0, blue: 0x69/255.0, alpha: 1.0)
                changeStatusButton?.layer.borderColor = UIColor(red: 0x34/255.0, green: 0xAA/255.0, blue: 0x69/255.0, alpha: 1.0).cgColor
            default:
                changeStatusButton?.isHidden = true
                changeWindowMessageLabel?.isHidden = true
            }
        }
    }

    /// Returns true if the decision was recorded less than 24 hours ago.
    private func isWithinChangeWindow() -> Bool {
        guard let ts = decisionTimestamp else {
            // No timestamp means the lender never changed from this device session,
            // or the 24 h already passed and was cleaned up. Treat as expired → return false.
            return false
        }
        return Date().timeIntervalSince(ts) < 24 * 60 * 60
    }

    // MARK: - Timestamp persistence helpers

    private func decisionKey(for requestId: String) -> String {
        "RW_DecisionTimestamp_\(requestId)"
    }

    private func saveDecisionTimestamp(_ date: Date, requestId: String) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: decisionKey(for: requestId))
    }

    private func loadDecisionTimestamp(requestId: String) -> Date? {
        let raw = UserDefaults.standard.double(forKey: decisionKey(for: requestId))
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    // MARK: - Owner name resolution

    private func resolveOwnerName(for ownerId: String) {
        Task {
            // Try users table first
            if let name = try? await fetchName(from: "users", ownerId: ownerId), !name.isEmpty {
                await MainActor.run { self.ownNameLabel?.text = capitalizingFirstLetter(name) }
                return
            }
            // Fallback to profiles
            if let name = try? await fetchName(from: "profiles", ownerId: ownerId), !name.isEmpty {
                await MainActor.run { self.ownNameLabel?.text = capitalizingFirstLetter(name) }
                return
            }
            await MainActor.run { self.ownNameLabel?.text = "Owner" }
        }
    }

    private func fetchName(from table: String, ownerId: String) async throws -> String? {
        struct NameDTO: Decodable { let full_name: String? }
        let response = try await SupabaseManager.shared.client
            .from(table)
            .select("full_name")
            .eq("id", value: ownerId)
            .single()
            .execute()

        if let data = response.data as? Data {
            let dto = try JSONDecoder().decode(NameDTO.self, from: data)
            return dto.full_name
        }
        return nil
    }

    private func capitalizingFirstLetter(_ s: String) -> String {
        guard let first = s.unicodeScalars.first else { return s }
        let firstChar = String(first).uppercased()
        let remainder = String(s.unicodeScalars.dropFirst())
        return firstChar + remainder
    }

    // MARK: - Build a lightweight Item to feed DistanceService

    private func makeShimItem(from req: RequestWithItem) -> Item {
        // Fill from joined item when available; otherwise minimal safe defaults
        let title = req.items?.title ?? req.item_id
        let images = req.items?.images ?? []
        let pricePerDay = req.items?.price_per_day ?? 0
        // Item requires many fields; populate sensible defaults where unknown
        return Item(
            id: req.item_id,
            owner_id: req.owner_id,
            title: title,
            description: nil,
            category: req.items?.category,
            condition: nil,
            price_per_day: pricePerDay,
            deposit_amount: 0,
            images: images,
            is_active: true,
            created_at: nil,
            updated_at: nil,
            average_rating: nil,
            review_count: nil
        )
    }

    // MARK: - Category fallback fetch

    private func fetchItemCategory(itemId: String) async -> String? {
        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("category")
                .eq("id", value: itemId)
                .single()
                .execute()

            struct Row: Decodable { let category: String? }
            if let data = response.data as? Data {
                let row = try JSONDecoder().decode(Row.self, from: data)
                if let cat = row.category, !cat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return cat
                }
            }
        } catch {
            // ignore; keep "—"
        }
        return nil
    }

    // MARK: - Pricing

    private func computeAndDisplayTotals(days: Int?, pricePerDay: Double?, itemId: String) {
        // If we already have deposit and needed inputs, compute immediately
        if let p = pricePerDay, let d = days, let deposit = depositAmount {
            let rentalFee = Double(d) * p
            let total = rentalFee + deposit
            secRateLabel?.text = currencyFormatter.string(from: NSNumber(value: deposit))
            totalLabel?.text = currencyFormatter.string(from: NSNumber(value: total))
            return
        }

        // Otherwise fetch deposit if missing, then compute
        Task {
            if depositAmount == nil {
                do {
                    struct DepositDTO: Decodable { let deposit_amount: Double }
                    let response = try await SupabaseManager.shared.client
                        .from("items")
                        .select("deposit_amount")
                        .eq("id", value: itemId)
                        .single()
                        .execute()

                    if let data = response.data as? Data {
                        let dto = try JSONDecoder().decode(DepositDTO.self, from: data)
                        self.depositAmount = dto.deposit_amount
                    }
                } catch {
                    // If fetch fails, assume zero deposit
                    self.depositAmount = 0
                }
            }

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                let deposit = self.depositAmount ?? 0
                if let d = days, let p = pricePerDay {
                    let rentalFee = Double(d) * p
                    let total = rentalFee + deposit
                    self.secRateLabel?.text = self.currencyFormatter.string(from: NSNumber(value: deposit))
                    self.totalLabel?.text = self.currencyFormatter.string(from: NSNumber(value: total))
                } else {
                    // Still show deposit if we have it
                    self.secRateLabel?.text = self.currencyFormatter.string(from: NSNumber(value: deposit))
                    // If we can’t compute total, leave it blank
                    if self.totalLabel?.text?.isEmpty ?? true {
                        self.totalLabel?.text = nil
                    }
                }
            }
        }
    }

    // MARK: - Actions: Accept / Deny

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "accepted") }
        // Notify BookingApprovalViewController that this request was accepted
        NotificationCenter.default.post(name: BookingApprovalViewController.requestApprovedNotification, object: nil)
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "denied") }
    }

    @objc private func didTapChangeStatus() {
        guard let current = request?.status.lowercased() else { return }
        guard isWithinChangeWindow() else {
            let alert = UIAlertController(
                title: "Window Closed",
                message: "You can only change your decision within 24 hours and before the borrower makes the payment.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Button title tells us what action to take
        let newStatus: String
        switch current {
        case "accepted": newStatus = "denied"
        case "denied":   newStatus = "accepted"
        default: return
        }

        let humanNew = newStatus.capitalized
        let confirm = UIAlertController(
            title: "Change to \(humanNew)?",
            message: "This will update your decision to \(humanNew). You can change it again within 24 hours or before the borrower pays.",
            preferredStyle: .alert
        )
        confirm.addAction(UIAlertAction(title: humanNew, style: .default, handler: { [weak self] _ in
            guard let self else { return }
            Task { await self.updateStatus(to: newStatus) }
        }))
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(confirm, animated: true)
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        view.isUserInteractionEnabled = enabled
        acceptButton?.alpha = enabled ? 1.0 : 0.6
        denyButton?.alpha = enabled ? 1.0 : 0.6
        denybutton?.alpha = enabled ? 1.0 : 0.6
        changeStatusButton?.isEnabled = enabled
        changeStatusButton?.alpha = enabled ? 1.0 : 0.6
    }

    private func updateStatus(to newStatus: String) async {
        guard var current = request else { return }
        await MainActor.run { self.setButtonsEnabled(false) }
        do {
            // PATCH requests set status = newStatus where id = current.id
            struct Patch: Encodable { let status: String }
            _ = try await SupabaseManager.shared.client
                .from("requests")
                .update(Patch(status: newStatus))
                .eq("id", value: current.id)
                .execute()

            // Update local model and UI
            current.status = newStatus
            self.request = current

            // Record when the decision was made and persist it across restarts
            let now = Date()
            self.decisionTimestamp = now
            if let reqId = self.request?.id {
                self.saveDecisionTimestamp(now, requestId: reqId)
            }

            await MainActor.run {
                // Update buttons/status row visibility
                self.updateButtonsAndStatusUI(status: current.status)
            }

            // Tell LenderView to refresh Requests
            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
        } catch {
            await MainActor.run {
                let alert = UIAlertController(title: "Update Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        await MainActor.run { self.setButtonsEnabled(true) }
    }
}
