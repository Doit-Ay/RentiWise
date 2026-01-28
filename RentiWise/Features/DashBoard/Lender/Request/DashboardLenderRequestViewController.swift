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
    private var changeStatusButton: UIButton?

    // White background bar behind the status row
    private var statusBackgroundView: UIView?
    private var statusBackgroundBottomConstraint: NSLayoutConstraint?

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

        setupChatButton()
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

        // Build inner stack: [ "Status: <value>", spacer, Change ]
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label

        let change = UIButton(type: .system)
        change.setTitle("Change", for: .normal)
        change.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        change.addTarget(self, action: #selector(didTapChangeStatus), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, UIView(), change])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Background container pinned to very bottom (not safe area), full width, white bg
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = .white // starts from bottom edge of screen
        // Rounded top corners like a bottom bar (optional)
        if #available(iOS 11.0, *) {
            bg.layer.cornerRadius = 16
            bg.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bg.layer.masksToBounds = true
        }

        // Always host in the main view so it sits at the bottom of the screen
        let host = view!
        host.addSubview(bg)
        bg.addSubview(stack)

        // Constrain background to bottom edges (view.bottomAnchor, not safe area)
        let leading = bg.leadingAnchor.constraint(equalTo: host.leadingAnchor)
        let trailing = bg.trailingAnchor.constraint(equalTo: host.trailingAnchor)
        let bottom = bg.bottomAnchor.constraint(equalTo: host.bottomAnchor) // <- to screen bottom
        NSLayoutConstraint.activate([leading, trailing, bottom])

        // Give the bar a minimum height so it feels like a bottom section
        let minHeight = bg.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        minHeight.priority = .required

        // Add content insets inside bg
        let topInset: CGFloat = 14
        let bottomInset: CGFloat = 28 // push content up a bit for visibility
        NSLayoutConstraint.activate([
            minHeight,
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: bg.topAnchor, constant: topInset),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -bottomInset)
        ])

        // Ensure it sits above other content visually
        host.bringSubviewToFront(bg)

        // Initially hidden until we have a non-pending status
        bg.isHidden = true
        stack.isHidden = true

        statusRowContainer = stack
        statusValueLabel = label
        changeStatusButton = change
        statusBackgroundView = bg
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

        // Title from joined item, fallback to item_id
        itemNameLabel?.text = req.items?.title ?? req.item_id

        // Category not present in RequestWithItem; leave blank or fetch if you need it
        categoryLabel?.text = ""

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

        // Pickup time raw for now
        if let t = req.pickup_time, !t.isEmpty {
            pickuptimeLabel?.text = t
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

        // Owner placeholders (ratings can be refined later)
        if ownRatingLabel?.text?.isEmpty ?? true { ownRatingLabel?.text = "★ 4.7" }
        
        // Calculate real distance asynchronously
        ownDistLabel?.text = "Calculating..."
        Task { [weak self] in
            guard let self = self else { return }
            let distanceText = await DistanceService.shared.calculateDistanceToItem(
                itemLatitude: req.items?.latitude,
                itemLongitude: req.items?.longitude
            )
            await MainActor.run {
                self.ownDistLabel?.text = distanceText
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

        // Accept/Deny buttons visible only when pending
        acceptButton?.isHidden = !isPending
        denyButton?.isHidden = !isPending
        denybutton?.isHidden = !isPending // keep in sync if this is wired to a second button

        // Status row + background visible only when not pending
        statusRowContainer?.isHidden = isPending
        statusBackgroundView?.isHidden = isPending

        if !isPending {
            let display = current.capitalized.isEmpty ? "—" : current.capitalized
            statusValueLabel?.text = "Status: \(display)"
        }
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

        let ac = UIAlertController(title: "Change Status", message: "Select a new status", preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Accepted", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            if current != "accepted" {
                Task { await self.updateStatus(to: "accepted") }
            }
        }))
        ac.addAction(UIAlertAction(title: "Denied", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            if current != "denied" {
                Task { await self.updateStatus(to: "denied") }
            }
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = ac.popoverPresentationController, let btn = changeStatusButton {
            pop.sourceView = btn
            pop.sourceRect = btn.bounds
        }
        present(ac, animated: true)
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        view.isUserInteractionEnabled = enabled
        acceptButton?.alpha = enabled ? 1.0 : 0.6
        denyButton?.alpha = enabled ? 1.0 : 0.6
        denybutton?.alpha = enabled ? 1.0 : 0.6
        changeStatusButton?.isEnabled = enabled
        changeStatusButton?.alpha = enabled ? 1.0 : 0.6
    }

    private func setupChatButton() {
        let chatBtn = UIBarButtonItem(image: UIImage(systemName: "message"), style: .plain, target: self, action: #selector(didTapChatButton))
        chatBtn.tintColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        navigationItem.rightBarButtonItem = chatBtn
    }

    @objc private func didTapChatButton() {
        guard let req = request else { return }
        
        let chatVC = ChatViewController()
        chatVC.otherUserId = req.borrower_id
        chatVC.itemId = req.item_id
        // Try to obtain borrower name if possible, or just "Borrower"
        // We can fetch it, or just pass nil and let ChatVC fetch/handle it.
        // For now, let's try to pass a placeholder like "Borrower"
        chatVC.otherUserName = "Borrower" 
        
        // Push
        navigationController?.pushViewController(chatVC, animated: true)
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

