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
    /// Legacy outlet — still wired in IB. To remove: disconnect it in IB first, then delete this line.
    @IBOutlet weak var denybutton: UIButton?

    // Programmatic status row (shown when status != pending)
    private var statusRowContainer: UIStackView?
    private var statusValueLabel: UILabel?
    private var changeStatusButton: UIButton?      // the single "Deny" or "Accept" action button
    private var changeWindowMessageLabel: UILabel? // "You can change within 24 h or before the rental starts"

    // White background bar behind the status row
    private var statusBackgroundView: UIView?
    private var statusBackgroundBottomConstraint: NSLayoutConstraint?
    private var isEnsuringPickupCode = false

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
        messageLabel.text = "You can change your decision within 24 hours or before the rental starts."

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
            updateVerificationAction()
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

        // Pricing: rental fee only for the TestFlight flow
        computeAndDisplayTotals(days: days, pricePerDay: req.items?.price_per_day, itemId: req.item_id)

        // Buttons vs status row
        updateButtonsAndStatusUI(status: req.status)
        updateVerificationAction()
        ensurePickupCodeIfNeeded(for: req)
    }

    private func updateButtonsAndStatusUI(status: String?) {
        let current = (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isPending = current.isEmpty || current == "pending"
        // Accept/Deny buttons visible only while pending
        acceptButton?.isHidden  = !isPending
        denyButton?.isHidden    = !isPending

        // Status bar visible when decision has been made
        let showBar = !isPending
        statusRowContainer?.isHidden    = !showBar
        statusBackgroundView?.isHidden  = !showBar

        guard showBar else { return }

        // Status label
        let display: String
        switch current {
        case "accepted":
            display = "Accepted • Awaiting OTP"
        case "approved":
            display = "Pickup Verified"
        default:
            display = current.capitalized.isEmpty ? "—" : current.capitalized
        }
        statusValueLabel?.text = "Status: \(display)"

        // Determine if the change window is still open.
        let windowOpen = isWithinChangeWindow()

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
            case "approved":
                changeStatusButton?.isHidden = true
                changeWindowMessageLabel?.isHidden = true
            default:
                changeStatusButton?.isHidden = true
                changeWindowMessageLabel?.isHidden = true
            }
        }
    }

    private func updateVerificationAction() {
        guard let req = request else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        let current = req.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasPickupCode = !(req.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if current == "accepted", hasPickupCode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Verify OTP",
                style: .plain,
                target: self,
                action: #selector(verifyPickupCodeTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func ensurePickupCodeIfNeeded(for req: RequestWithItem) {
        let current = req.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasPickupCode = !(req.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard current == "accepted", !hasPickupCode, !isEnsuringPickupCode else { return }

        isEnsuringPickupCode = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isEnsuringPickupCode = false }
            do {
                let generatedCode = self.generatePickupCode()
                try await self.persistRequest(status: "accepted", pickupCode: generatedCode)
                try await self.setItemAvailability(itemId: req.item_id, isActive: false)
                await MainActor.run {
                    self.request?.pickup_code = generatedCode
                    self.updateButtonsAndStatusUI(status: self.request?.status)
                    self.updateVerificationAction()
                }
            } catch {
                debugLog("[LenderRequest] Failed to backfill pickup code: \(error)")
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
        let date = Date(timeIntervalSince1970: raw)
        // If the window has already closed, clean up the stale key and return nil
        if Date().timeIntervalSince(date) >= 24 * 60 * 60 {
            UserDefaults.standard.removeObject(forKey: decisionKey(for: requestId))
            return nil
        }
        return date
    }

    // MARK: - Owner name resolution

    private func resolveOwnerName(for ownerId: String) {
        Task {
            // Try users table
            if let name = try? await fetchName(from: "users", ownerId: ownerId), !name.isEmpty {
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
        _ = itemId
        secRateLabel?.text = "Direct via UPI"

        guard let d = days, let p = pricePerDay else {
            if totalLabel?.text?.isEmpty ?? true {
                totalLabel?.text = nil
            }
            return
        }

        let rentalFee = Double(d) * p
        totalLabel?.text = currencyFormatter.string(from: NSNumber(value: rentalFee))
    }

    // MARK: - Actions: Accept / Deny

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "accepted") }
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "denied") }
    }

    @objc private func didTapChangeStatus() {
        guard let current = request?.status.lowercased() else { return }
        guard isWithinChangeWindow() else {
            let alert = UIAlertController(
                title: "Window Closed",
                message: "You can only change your decision within 24 hours and before the rental starts.",
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
            message: "This will update your decision to \(humanNew). You can change it again within 24 hours or before the rental starts.",
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
        changeStatusButton?.isEnabled = enabled
        changeStatusButton?.alpha = enabled ? 1.0 : 0.6
        navigationItem.rightBarButtonItem?.isEnabled = enabled
    }

    private func assertCurrentLenderCanAcceptRequest() async throws {
        let profile = try await ProfileService().fetchCurrentUserProfile()
        let upiId = profile.upiId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !upiId.isEmpty else {
            throw NSError(
                domain: "Rentiwise.Requests",
                code: 422,
                userInfo: [
                    NSLocalizedDescriptionKey: "Add your UPI ID in Profile before accepting a request so the borrower can pay you directly."
                ]
            )
        }
    }

    private func updateStatus(to newStatus: String) async {
        guard var current = request else { return }
        await MainActor.run { self.setButtonsEnabled(false) }
        do {
            let previousStatus = current.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let nextPickupCode: String?
            switch newStatus {
            case "accepted":
                try await assertCurrentLenderCanAcceptRequest()
                try await assertNoActiveRentalConflict(for: current)
                nextPickupCode = current.pickup_code?.isEmpty == false ? current.pickup_code : generatePickupCode()
            case "denied":
                nextPickupCode = nil
            default:
                nextPickupCode = current.pickup_code
            }

            try await persistRequest(status: newStatus, pickupCode: nextPickupCode)

            if newStatus == "accepted" {
                try await setItemAvailability(itemId: current.item_id, isActive: false)
            } else if newStatus == "denied", previousStatus == "accepted" || previousStatus == "approved" {
                try await setItemAvailability(itemId: current.item_id, isActive: true)
            }

            // Update local model and UI
            current.status = newStatus
            current.pickup_code = nextPickupCode
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
                self.updateVerificationAction()
            }

            // Tell LenderView to refresh Requests
            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
            if newStatus == "accepted" {
                NotificationCenter.default.post(name: BookingApprovalViewController.requestApprovedNotification, object: nil)
                // Schedule a due-date reminder local notification for the borrower
                NotificationService.shared.scheduleRentalDueReminder(
                    requestId: current.id,
                    itemTitle: current.items?.title ?? "Item",
                    endDateString: current.end_date
                )
            }
            // Send local push notification for status change
            let statusEnum = RentalStatus(rawDBValue: newStatus)
            NotificationService.shared.notifyStatusChange(
                requestId: current.id,
                itemTitle: current.items?.title ?? "Item",
                newStatus: statusEnum,
                role: "lender"
            )

            // Track analytics event for lender decision
            AnalyticsService.shared.trackRequestDecision(requestId: current.id, decision: newStatus)
        } catch {
            await MainActor.run {
                let alert = UIAlertController(title: "Update Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        await MainActor.run { self.setButtonsEnabled(true) }
    }

    private func assertNoActiveRentalConflict(for current: RequestWithItem) async throws {
        struct ActiveRequestRow: Decodable { let id: String }

        let response = try await SupabaseManager.shared.client
            .from("requests")
            .select("id")
            .eq("item_id", value: current.item_id)
            .in("status", values: ["accepted", "approved"])
            .neq("id", value: current.id)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([ActiveRequestRow].self, from: response.data)
        guard rows.isEmpty else {
            throw NSError(
                domain: "Rentiwise.Requests",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "This item already has an active rental. Complete or cancel the other booking before accepting another request."]
            )
        }
    }

    private func generatePickupCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    private func persistRequest(status: String, pickupCode: String?) async throws {
        struct Patch: Encodable {
            let status: String
            let pickup_code: String?
        }

        guard let requestId = request?.id else { return }
        _ = try await SupabaseManager.shared.client
            .from("requests")
            .update(Patch(status: status, pickup_code: pickupCode))
            .eq("id", value: requestId)
            .execute()
    }

    private func setItemAvailability(itemId: String, isActive: Bool) async throws {
        struct ItemPatch: Encodable { let is_active: Bool }

        _ = try await SupabaseManager.shared.client
            .from("items")
            .update(ItemPatch(is_active: isActive))
            .eq("id", value: itemId)
            .execute()
    }

    @objc private func verifyPickupCodeTapped() {
        guard let req = request else { return }
        guard let expectedCode = req.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines), !expectedCode.isEmpty else {
            let alert = UIAlertController(title: "OTP Missing", message: "A pickup OTP has not been generated for this request yet.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: "Verify Pickup OTP",
            message: "Ask the borrower for the 6-digit pickup code to confirm the handoff.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "6-digit OTP"
            textField.keyboardType = .numberPad
            textField.textContentType = .oneTimeCode
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Verify", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let typed = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard typed == expectedCode else {
                let mismatch = UIAlertController(title: "Incorrect OTP", message: "The code doesn't match the borrower's pickup code.", preferredStyle: .alert)
                mismatch.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(mismatch, animated: true)
                return
            }

            Task { [weak self] in
                guard let self else { return }
                await self.completePickupVerification()
            }
        })
        present(alert, animated: true)
    }

    private func completePickupVerification() async {
        guard var current = request else { return }
        await MainActor.run { self.setButtonsEnabled(false) }
        do {
            try await persistRequest(status: "approved", pickupCode: nil)
            current.status = "approved"
            current.pickup_code = nil
            request = current

            // Auto-create rental history row on pickup verification
            await createRentalHistoryIfNeeded(for: current)

            await MainActor.run {
                self.updateButtonsAndStatusUI(status: current.status)
                self.updateVerificationAction()
                let alert = UIAlertController(title: "Pickup Verified", message: "The OTP matched and the rental is now marked as active.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }

            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)

            // Track analytics event
            AnalyticsService.shared.trackPickupVerified(requestId: current.id)
        } catch {
            await MainActor.run {
                let alert = UIAlertController(title: "Verification Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        await MainActor.run { self.setButtonsEnabled(true) }
    }

    // MARK: - Rental History Auto-Creation

    /// Creates a row in `rentals_history` when the pickup OTP is verified (status becomes "approved").
    /// This ensures the lender's history tab populates automatically.
    private func createRentalHistoryIfNeeded(for req: RequestWithItem) async {
        struct ExistingHistoryRow: Decodable { let id: String }

        // Check if a history row already exists for this request
        do {
            let existing = try await SupabaseManager.shared.client
                .from("rentals_history")
                .select("id")
                .eq("request_id", value: req.id)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([ExistingHistoryRow].self, from: existing.data)
            if !rows.isEmpty {
                debugLog("[LenderRequest] Rental history row already exists for request \(req.id)")
                return
            }
        } catch {
            // Table might not have request_id column yet — proceed anyway
            debugLog("[LenderRequest] Could not check existing history: \(error)")
        }

        // Compute total amount
        let sqlDF = DateFormatter()
        sqlDF.calendar = Calendar(identifier: .gregorian)
        sqlDF.timeZone = TimeZone(secondsFromGMT: 0)
        sqlDF.dateFormat = "yyyy-MM-dd"
        var days = 1
        if let s = sqlDF.date(from: req.start_date), let e = sqlDF.date(from: req.end_date) {
            days = max(1, Int(ceil(e.timeIntervalSince(s) / 86400.0)))
        }
        let pricePerDay = req.items?.price_per_day ?? 0
        let totalAmount = Double(days) * pricePerDay

        struct HistoryInsert: Encodable {
            let item_id: String
            let owner_id: String
            let borrower_id: String
            let start_date: String
            let end_date: String
            let total_amount: Double
            let request_id: String
        }

        let row = HistoryInsert(
            item_id: req.item_id,
            owner_id: req.owner_id,
            borrower_id: req.borrower_id,
            start_date: req.start_date,
            end_date: req.end_date,
            total_amount: totalAmount,
            request_id: req.id
        )

        do {
            _ = try await SupabaseManager.shared.client
                .from("rentals_history")
                .insert(row)
                .execute()
            debugLog("[LenderRequest] Rental history row created for request \(req.id)")
        } catch {
            debugLog("[LenderRequest] Failed to create rental history: \(error)")
        }
    }

    // MARK: - Pending Sub-Requests Section

    /// Container for the pending sub-requests section (shown below pricing card for active rentals).
    private var pendingSubRequestsStack: UIStackView?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Load pending return/extension requests for this booking
        if let req = request {
            let status = req.status.lowercased()
            if status == "accepted" || status == "approved" {
                Task { await loadPendingSubRequests(for: req.id) }
            }
        }
    }

    private func loadPendingSubRequests(for requestId: String) async {
        struct PendingSubRequest: Decodable {
            let id: String
            let status: String
            let created_at: String?
        }

        var returnRequests: [PendingSubRequest] = []
        var extensionRequests: [PendingSubRequest] = []

        // Fetch pending return requests
        do {
            let resp = try await SupabaseManager.shared.client
                .from("return_requests")
                .select("id, status, created_at")
                .eq("request_id", value: requestId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
            returnRequests = try JSONDecoder().decode([PendingSubRequest].self, from: resp.data)
        } catch {
            debugLog("[LenderRequest] Error loading pending return requests: \(error)")
        }

        // Fetch pending extension requests
        do {
            let resp = try await SupabaseManager.shared.client
                .from("extension_requests")
                .select("id, status, created_at")
                .eq("request_id", value: requestId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
            extensionRequests = try JSONDecoder().decode([PendingSubRequest].self, from: resp.data)
        } catch {
            debugLog("[LenderRequest] Error loading pending extension requests: \(error)")
        }

        await MainActor.run {
            self.displayPendingSubRequests(returnRequests: returnRequests.map { ($0.id, "return") },
                                           extensionRequests: extensionRequests.map { ($0.id, "extension") })
        }
    }

    private func displayPendingSubRequests(returnRequests: [(id: String, type: String)],
                                            extensionRequests: [(id: String, type: String)]) {
        // Remove existing section if any
        pendingSubRequestsStack?.removeFromSuperview()
        pendingSubRequestsStack = nil

        let allPending = returnRequests + extensionRequests
        guard !allPending.isEmpty, let priceCard = priceCard else { return }

        let tealColor = UIColor(red: 93/255.0, green: 169/255.0, blue: 182/255.0, alpha: 1.0)

        // Section header
        let headerLabel = UILabel()
        headerLabel.text = "📋 Pending Requests"
        headerLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headerLabel.textColor = .label

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(headerLabel)

        for pending in allPending {
            let rowView = UIView()
            rowView.backgroundColor = .secondarySystemGroupedBackground
            rowView.layer.cornerRadius = 12
            rowView.layer.masksToBounds = true
            rowView.translatesAutoresizingMaskIntoConstraints = false
            rowView.heightAnchor.constraint(equalToConstant: 52).isActive = true

            let icon = UIImageView(image: UIImage(systemName: pending.type == "return" ? "arrow.uturn.backward.circle.fill" : "calendar.badge.plus"))
            icon.tintColor = .systemOrange
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 24).isActive = true

            let label = UILabel()
            label.text = pending.type == "return" ? "Return Request" : "Extension Request"
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = .label
            label.translatesAutoresizingMaskIntoConstraints = false

            let reviewButton = UIButton(type: .system)
            reviewButton.setTitle("Review", for: .normal)
            reviewButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            reviewButton.tintColor = .white
            reviewButton.backgroundColor = tealColor
            reviewButton.layer.cornerRadius = 8
            reviewButton.layer.masksToBounds = true
            reviewButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            reviewButton.translatesAutoresizingMaskIntoConstraints = false
            // Tag encodes the request type and ID for the action handler
            reviewButton.accessibilityIdentifier = "\(pending.type)|\(pending.id)"
            reviewButton.addTarget(self, action: #selector(didTapReviewSubRequest(_:)), for: .touchUpInside)

            rowView.addSubview(icon)
            rowView.addSubview(label)
            rowView.addSubview(reviewButton)

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 14),
                icon.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                reviewButton.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -14),
                reviewButton.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: reviewButton.leadingAnchor, constant: -8)
            ])

            stack.addArrangedSubview(rowView)
        }

        // Add section to view, below priceCard
        guard let scrollView = priceCard.superview else { return }
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: priceCard.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: priceCard.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: priceCard.trailingAnchor)
        ])

        pendingSubRequestsStack = stack
    }

    @objc private func didTapReviewSubRequest(_ sender: UIButton) {
        guard let identifier = sender.accessibilityIdentifier,
              let requestId = request?.id else { return }
        let parts = identifier.split(separator: "|")
        guard parts.count == 2 else { return }
        let typeName = String(parts[0])
        let subRequestId = String(parts[1])

        let nibName = "RequestApprovalViewController"
        let approvalVC: RequestApprovalViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
           Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            approvalVC = RequestApprovalViewController(nibName: nibName, bundle: nil)
        } else {
            approvalVC = RequestApprovalViewController()
        }

        let requestType: RequestType = typeName == "return" ? .returnRequest : .extensionRequest
        approvalVC.configure(requestType: requestType, requestId: subRequestId, bookingId: requestId)
        approvalVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(approvalVC, animated: true)
    }
}
