//  BookingApprovalViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit
import Supabase

class BookingApprovalViewController: UIViewController {

    enum RequestStatus {
        case approved
        case pending
    }

    static let requestApprovedNotification = Notification.Name("BookingApprovalRequestApprovedNotification")

    // Inject the selected request from the caller (e.g., MyRentalsViewController)
    var request: RequestWithItem? {
        didSet {
            if isViewLoaded {
                applyRequestToUI()
            }
        }
    }

    // Current request status; set this from outside as needed
    var status: RequestStatus = .pending {
        didSet {
            print("[BookingApproval] Status changed to: \(status)")
            updateStatusUI()
        }
    }

    // Booking dates passed from RequestViewController or mapped from request
    private var startDate: Date?
    private var pickupTime: Date?
    private var returnTime: Date?

    // Derived exclusively from DB: whether there is a succeeded payment for this request
    private var hasCompletedPayment: Bool = false

    // The active/latest payment row (if any) loaded from DB
    private var currentPayment: PaymentRow?

    // Observer token to manage notification observer lifecycle
    private var approvalObserver: NSObjectProtocol?
    private var requestsRefreshObserver: NSObjectProtocol?

    // IBOutlets
    
    @IBOutlet weak var getdirectionbutton: UIButton!
    @IBOutlet weak var copybutton: UIButton!
    @IBOutlet weak var paymentButton: UIButton!

    @IBOutlet weak var outerblueCard: UIView!
    @IBOutlet weak var inneRCard: UIView!
    @IBOutlet weak var imageprod: UIImageView!
    @IBOutlet weak var nameofitemLabel: UILabel!
    @IBOutlet weak var categoryitemLabel: UILabel!
    
    @IBOutlet weak var statusView: UIView!

    @IBOutlet weak var circ1: UIView!
    @IBOutlet weak var circ2: UIView!
    @IBOutlet weak var circ3: UIView!

    // New container that holds ONLY the "View Code" button and the stack
    @IBOutlet weak var viewCodeUIView: UIView!
    @IBOutlet weak var codestack: UIStackView!

    // Code digit views
    @IBOutlet weak var c1view: UIView!
    @IBOutlet weak var code1Label: UILabel!
    @IBOutlet weak var c2view: UIView!
    @IBOutlet weak var code2Label: UILabel!
    @IBOutlet weak var c3view: UIView!
    @IBOutlet weak var code3Label: UILabel!
    @IBOutlet weak var c4view: UIView!
    @IBOutlet weak var code4Label: UILabel!
    @IBOutlet weak var c5view: UIView!
    @IBOutlet weak var code5Label: UILabel!
    @IBOutlet weak var c6view: UIView!
    @IBOutlet weak var code6Label: UILabel!
    @IBOutlet weak var price: UIView!
    @IBOutlet weak var addresscard: UIView!
    @IBOutlet weak var summary: UIView!
    
    @IBOutlet weak var dateperiodLabel: UILabel!
    @IBOutlet weak var picktimeLabel: UILabel!
    @IBOutlet weak var numLabeldays: UILabel!
    
    
    @IBOutlet weak var ownerProfileImage: UIImageView!
    @IBOutlet weak var ownNameLabel: UILabel!
    @IBOutlet weak var rateOwnerlabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var fee: UILabel!
    @IBOutlet weak var seclabel: UILabel!
    @IBOutlet weak var totamountlabel: UILabel!
    @IBOutlet weak var tickimage: UIImageView!
    @IBOutlet weak var approvedpending: UILabel!
    
    // Constraint from statusView's bottom to viewCodeUIView's top
    @IBOutlet weak var statusToViewCodeTop: NSLayoutConstraint!
    // Height constraint for the new "View Code" container
    @IBOutlet weak var viewCodeHeight: NSLayoutConstraint!

    // Collapse/expand helpers
    private var codeStackCollapseConstraint: NSLayoutConstraint?

    // Heights
    private let collapsedViewCodeHeight: CGFloat = 56
    private let expandedViewCodeHeight: CGFloat = 140

    // Formatters for mapping DB strings to Date
    private lazy var sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    private lazy var timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
    private lazy var sqlTimeParser: DateFormatter = {
        // pickup_time saved as "HH:mm:ssXXXXX" (from RequestViewController)
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "HH:mm:ssXXXXX"
        return df
    }()
    private lazy var currencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        // Optional: explicitly set INR; if device locale already uses INR you can omit this.
        nf.currencyCode = "INR"
        return nf
    }()

    // Track whether we hid the tab bar so we can restore it
    private var didHideTabBarManually = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure tab bar hides when this VC is pushed
        self.hidesBottomBarWhenPushed = true

        // Round all corners of statusView
        statusView.layer.cornerRadius = 20
        statusView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        statusView.layer.masksToBounds = true

        // Round only bottom corners of viewCodeUIView
        viewCodeUIView.layer.cornerRadius = 20
        viewCodeUIView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        viewCodeUIView.layer.masksToBounds = true

        // Circles
        circ1.layer.cornerRadius = circ1.bounds.height / 2
        circ1.layer.masksToBounds = true
        circ2.layer.cornerRadius = circ2.bounds.height / 2
        circ2.layer.masksToBounds = true
        circ3.layer.cornerRadius = circ3.bounds.height / 2
        circ3.layer.masksToBounds = true

        // Code digit boxes styling
        let codeViews: [UIView?] = [c1view, c2view, c3view, c4view, c5view, c6view]
        let borderColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0).cgColor
        codeViews.forEach { v in
            v?.layer.cornerRadius = 12
            v?.layer.borderWidth = 2
            v?.layer.borderColor = borderColor
            v?.layer.masksToBounds = true
        }

        // Prepare a reusable collapse constraint for the code stack
        if codeStackCollapseConstraint == nil {
            codeStackCollapseConstraint = codestack.heightAnchor.constraint(equalToConstant: 0)
        }

        // Start collapsed: show only the button, hide the stack
        codestack.isHidden = true
        codeStackCollapseConstraint?.isActive = true
        // Hide code view until payment completes and collapse its height/spacing
        viewCodeUIView.isHidden = true
        viewCodeHeight?.constant = 0
        viewCodeHeight?.isActive = true
        statusToViewCodeTop?.constant = 0

        // Style buttons
        [paymentButton, getdirectionbutton, copybutton].forEach {
            $0?.layer.borderColor = UIColor.black.cgColor
            $0?.layer.borderWidth = 1
            $0?.layer.cornerRadius = 8
            $0?.layer.masksToBounds = true
        }

        // Ensure owner image is circular
        ownerProfileImage?.clipsToBounds = true
        ownerProfileImage?.contentMode = .scaleAspectFill

        // Round product image corners
        imageprod?.clipsToBounds = true
        imageprod?.layer.cornerRadius = 16

        // Start in Pending state and disable payment until accepted
        status = .pending
        paymentButton.isEnabled = false
        paymentButton.alpha = 0.5

        // Initialize status UI based on current status
        updateStatusUI()

        // Reflect any pre-configured dates
        updateDatesUI()

        // If a request is already injected, apply it now
        applyRequestToUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Make avatar circular based on actual size
        ownerProfileImage?.layer.cornerRadius = (ownerProfileImage?.bounds.height ?? 0) / 2
        ownerProfileImage?.layer.masksToBounds = true

        // Re-assert rounded corners for the product image in case layout changes
        imageprod?.layer.cornerRadius = 16
        imageprod?.clipsToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Redundantly ensure this VC hides bottom bar when pushed
        hidesBottomBarWhenPushed = true

        // If we’re not pushed in a nav that hides the tab bar, hide tab bar manually (covers SwiftUI-hosted path)
        ensureTabBarHiddenIfNeeded()

        updateDatesUI()

        if approvalObserver == nil {
            approvalObserver = NotificationCenter.default.addObserver(forName: BookingApprovalViewController.requestApprovedNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                print("[BookingApproval] Notification received: requestApprovedNotification")
                self.setStatus(.approved)
            }
        }
        if requestsRefreshObserver == nil {
            requestsRefreshObserver = NotificationCenter.default.addObserver(forName: Notification.Name("requestsShouldRefresh"), object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                print("[BookingApproval] Notification received: requestsShouldRefresh -> marking Approved")
                self.setStatus(.approved)
                Task { await self.refreshRequestFromDBIfPossible() }
            }
        }

        Task {
            await refreshRequestFromDBIfPossible()
            await refreshPaymentFromDB()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // If we hid the tab bar manually for this screen, restore it when leaving
        restoreTabBarIfNeeded()

        if let token = approvalObserver {
            NotificationCenter.default.removeObserver(token)
            approvalObserver = nil
        }
        if let token = requestsRefreshObserver {
            NotificationCenter.default.removeObserver(token)
            requestsRefreshObserver = nil
        }
    }
    
    func setStatus(_ newStatus: RequestStatus) {
        self.status = newStatus
    }

    func configureDates(startDate: Date?, pickupTime: Date?, returnTime: Date?) {
        self.startDate = startDate
        self.pickupTime = pickupTime
        self.returnTime = returnTime
        updateDatesUI()
    }

    func didSelectNewProductFromMyRentals() {
        hasCompletedPayment = false
        currentPayment = nil
        viewCodeUIView.isHidden = true
        statusToViewCodeTop?.constant = 16
        paymentButton.setTitle("Proceed to Payment", for: .normal)
        updateStatusUI()
    }

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        // Borrower cannot accept here; status comes from owner and DB.
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        // Borrower cannot deny here; status comes from owner and DB.
    }

    @IBAction func ViewHideCodeButton(_ sender: UIButton) {
        let isCurrentlyShowingCode = (sender.title(for: .normal) ?? "") == "Hide Code"
        let shouldShowCode = !isCurrentlyShowingCode

        sender.setTitle(shouldShowCode ? "Hide Code" : "View Code", for: .normal)

        if shouldShowCode {
            codeStackCollapseConstraint?.isActive = false
            codestack.isHidden = false
            viewCodeHeight?.constant = expandedViewCodeHeight
            viewCodeHeight?.isActive = true
        } else {
            codeStackCollapseConstraint?.isActive = true
            codestack.isHidden = true
            viewCodeHeight?.constant = collapsedViewCodeHeight
            viewCodeHeight?.isActive = true
        }

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func openChat() {
        let chatVC = ChatViewController(nibName: "ChatViewController", bundle: nil)
        if let nav = self.navigationController {
            nav.pushViewController(chatVC, animated: true)
        } else {
            chatVC.modalPresentationStyle = .fullScreen
            self.present(chatVC, animated: true)
        }
    }

    @IBAction func openChatButtonTapped(_ sender: Any) {
        openChat()
    }
    
    @IBAction func paymentbuttontapped(_ sender: UIButton) {
        guard let req = request else { return }

        let actionSheet = UIAlertController(title: "Choose Payment Method", message: nil, preferredStyle: .actionSheet)

        let handlePaymentSelection: (String) -> Void = { method in
            Task { await self.performDBBackedPayment(for: req, provider: method, button: sender) }
        }

        actionSheet.addAction(UIAlertAction(title: "Apple Pay", style: .default) { _ in handlePaymentSelection("apple_pay") })
        actionSheet.addAction(UIAlertAction(title: "Credit/Debit Card", style: .default) { _ in handlePaymentSelection("card") })
        actionSheet.addAction(UIAlertAction(title: "Cash on Delivery", style: .default) { _ in handlePaymentSelection("cod") })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }

        present(actionSheet, animated: true)
    }
    
    @IBAction func debugForceApprove(_ sender: Any) {
        print("[BookingApproval] debugForceApprove tapped")
        setStatus(.approved)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: BookingApprovalViewController.requestApprovedNotification, object: nil)
    }

    // MARK: - Private helpers

    private func updateDatesUI() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        if let s = startDate {
            dateperiodLabel.text = dateFormatter.string(from: s)
        } else {
            dateperiodLabel.text = ""
        }

        if let p = pickupTime {
            picktimeLabel.text = timeFormatter.string(from: p)
        } else {
            picktimeLabel.text = ""
        }

        if let s = startDate, let r = returnTime {
            let days = max(1, Int(ceil(r.timeIntervalSince(s) / 86400.0)))
            numLabeldays.text = "\(days) Days"
        } else {
            numLabeldays.text = ""
        }
    }
    
    private func setCodeDigits(from code: String) {
        let chars = Array(code)
        let digits: [String] = (0..<6).map { idx in
            if idx < chars.count, chars[idx].isNumber || chars[idx].isLetter {
                return String(chars[idx]).uppercased()
            } else {
                return "0"
            }
        }
        let labels: [UILabel?] = [code1Label, code2Label, code3Label, code4Label, code5Label, code6Label]
        for (i, lbl) in labels.enumerated() {
            lbl?.text = digits[i]
        }
    }

    private func generatePickupCode() -> String {
        (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined()
    }

    private func updateStatusUI() {
        switch status {
        case .approved:
            approvedpending.text = "Approved"
            tickimage.image = UIImage(systemName: "checkmark.circle")
            tickimage.tintColor = .white
            paymentButton.isEnabled = true
            paymentButton.alpha = 1.0
        case .pending:
            approvedpending.text = "Pending"
            tickimage.image = UIImage(systemName: "questionmark.circle.dashed")
            tickimage.tintColor = .white
            paymentButton.isEnabled = false
            paymentButton.alpha = 0.5
        }

        tickimage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        tickimage.contentMode = .scaleAspectFit

        // Show/hide View Code container depending on DB payment status
        let shouldShowCode = hasCompletedPayment
        viewCodeUIView.isHidden = !shouldShowCode
        if shouldShowCode {
            viewCodeHeight?.constant = collapsedViewCodeHeight
            statusToViewCodeTop?.constant = 0
        } else {
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
        }

        // Button title from payment state
        if hasCompletedPayment {
            paymentButton.setTitle("Payment Successful", for: .normal)
            // Ensure title text is black for both normal and disabled states
            paymentButton.setTitleColor(.black, for: .normal)
            paymentButton.setTitleColor(.black, for: .disabled)
            paymentButton.isEnabled = false
            paymentButton.alpha = 0.6
        } else {
            paymentButton.setTitle("Proceed to Payment", for: .normal)
            // Restore a suitable title color for the normal actionable state
            paymentButton.setTitleColor(.label, for: .normal)
            // Optionally also set .disabled for consistency when pending
            paymentButton.setTitleColor(.secondaryLabel, for: .disabled)
            // Enable only if request is approved
            paymentButton.isEnabled = (status == .approved)
            paymentButton.alpha = paymentButton.isEnabled ? 1.0 : 0.5
        }
    }

    private func applyRequestToUI() {
        guard let req = request else { return }

        // Map status string to RequestStatus (accepted/approved -> approved)
        let s = req.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "accepted" || s == "approved" {
            setStatus(.approved)
        } else {
            setStatus(.pending)
        }

        // Dates
        let sDate = sqlDateFormatter.date(from: req.start_date)
        let eDate = sqlDateFormatter.date(from: req.end_date)
        let pTime = (req.pickup_time != nil && !(req.pickup_time ?? "").isEmpty) ? sqlTimeParser.date(from: req.pickup_time!) : nil
        self.startDate = sDate
        self.returnTime = eDate
        self.pickupTime = pTime
        updateDatesUI()

        // Title/image
        nameofitemLabel?.text = req.items?.title ?? req.item_id
        if let path = req.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    self?.imageprod?.image = img
                    self?.imageprod?.contentMode = .scaleAspectFill
                    self?.imageprod?.clipsToBounds = true
                }
            }
        } else {
            imageprod?.image = UIImage(systemName: "photo")
            imageprod?.tintColor = .secondaryLabel
            imageprod?.contentMode = .scaleAspectFit
        }

        // Category
        if let cat = req.items?.category, !cat.isEmpty {
            categoryitemLabel?.text = cat
        } else {
            categoryitemLabel?.text = "" // or "Uncategorized" if you prefer
        }

        // Owner info
        Task { [weak self] in
            guard let self = self else { return }
            await self.fetchAndDisplayOwnerUnified(for: req.owner_id)
        }

        // Update amount labels for the current request
        Task { [weak self] in
            guard let self = self, let req = self.request else { return }
            let amounts = await self.computeAmounts(for: req)
            await MainActor.run {
                self.updateAmountLabels(rental: amounts.rentalFee, deposit: amounts.deposit, total: amounts.rentalFee + amounts.deposit)
            }
        }

        // Always reflect latest payment from DB
        Task { await self.refreshPaymentFromDB() }
    }

    private func selectClause() -> String {
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day,category)
        """
    }

    private func mapRefreshedRow(_ fresh: RequestWithItem) {
        self.request = fresh
    }

    private func refreshRequestFromDBIfPossible() async {
        guard let id = request?.id else { return }
        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(selectClause())
                .eq("id", value: id)
                .single()
                .execute()
            let fresh = try JSONDecoder().decode(RequestWithItem.self, from: response.data)
            await MainActor.run { self.mapRefreshedRow(fresh) }
        } catch {
            // ignore
        }
    }

    // MARK: - Payments (DB-driven)

    private func refreshPaymentFromDB() async {
        guard let req = request else { return }
        do {
            let response = try await SupabaseManager.shared.client
                .from("payments")
                .select()
                .eq("request_id", value: req.id)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            let decoder = JSONDecoder()
            let rows = try decoder.decode([PaymentRow].self, from: response.data)
            let latest = rows.first

            await MainActor.run {
                self.currentPayment = latest
                if let p = latest, p.status.lowercased() == "succeeded", let code = p.pickup_code, !code.isEmpty {
                    self.hasCompletedPayment = true
                    self.setCodeDigits(from: code)
                    // Also reflect paid amounts if present
                    self.updateAmountLabels(rental: p.rental_fee, deposit: p.deposit_amount, total: p.total_amount)
                } else {
                    self.hasCompletedPayment = false
                    // Clear code digits visually
                    self.setCodeDigits(from: "000000")
                    // Recompute from request for display
                    Task { [weak self] in
                        guard let self = self, let req = self.request else { return }
                        let amounts = await self.computeAmounts(for: req)
                        await MainActor.run {
                            self.updateAmountLabels(rental: amounts.rentalFee, deposit: amounts.deposit, total: amounts.rentalFee + amounts.deposit)
                        }
                    }
                }
                self.updateStatusUI()
            }
        } catch {
            await MainActor.run {
                self.currentPayment = nil
                self.hasCompletedPayment = false
                self.setCodeDigits(from: "000000")
                // Fall back to computed values
                Task { [weak self] in
                    guard let self = self, let req = self.request else { return }
                    let amounts = await self.computeAmounts(for: req)
                    await MainActor.run {
                        self.updateAmountLabels(rental: amounts.rentalFee, deposit: amounts.deposit, total: amounts.rentalFee + amounts.deposit)
                        self.updateStatusUI()
                    }
                }
            }
        }
    }

    private func performDBBackedPayment(for req: RequestWithItem, provider: String, button: UIButton) async {
        await MainActor.run {
            button.isEnabled = false
            button.alpha = 0.6
        }
        defer {
            Task { @MainActor in
                button.isEnabled = true
                button.alpha = 1.0
            }
        }

        // 1) If already succeeded, just refresh UI
        await refreshPaymentFromDB()
        if let p = currentPayment, p.status.lowercased() == "succeeded" {
            await MainActor.run {
                self.updateStatusUI()
            }
            return
        }

        // 2) Compute amounts (days * price_per_day + deposit)
        let amounts = await computeAmounts(for: req)
        let rentalFee = amounts.rentalFee
        let deposit = amounts.deposit
        let total = rentalFee + deposit

        // Update labels immediately while we proceed
        await MainActor.run {
            self.updateAmountLabels(rental: rentalFee, deposit: deposit, total: total)
        }

        // 3) INSERT pending payment
        let insert = PaymentInsert(
            request_id: req.id,
            item_id: req.item_id,
            owner_id: req.owner_id,
            borrower_id: req.borrower_id,
            provider: provider,
            status: "pending",
            currency: "INR",
            rental_fee: rentalFee,
            deposit_amount: deposit,
            total_amount: total
        )

        do {
            _ = try await SupabaseManager.shared.client
                .from("payments")
                .insert(insert)
                .execute()

            // Optional event log:
            // try? await insertPaymentEvent(type: "created", message: "Payment created (pending)")

        } catch {
            await MainActor.run {
                let ac = UIAlertController(title: "Payment Failed", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
            }
            return
        }

        // 4) UPDATE to succeeded with pickup_code (simulate capture/confirmation)
        let code = generatePickupCode()
        let update = PaymentUpdate(status: "succeeded", pickup_code: code, provider_payment_id: nil, provider_receipt_url: nil, failure_reason: nil)

        do {
            // Update latest pending payment for this request (policy allows borrower to update pending)
            _ = try await SupabaseManager.shared.client
                .from("payments")
                .update(update)
                .eq("request_id", value: req.id)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()

            // Optional event log:
            // try? await insertPaymentEvent(type: "captured", message: "Payment succeeded; code issued")

        } catch {
            await MainActor.run {
                let ac = UIAlertController(title: "Finalize Failed", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
            }
            return
        }

        // 5) Re-read from DB and update UI
        await refreshPaymentFromDB()
    }

    private func computeAmounts(for req: RequestWithItem) async -> (rentalFee: Double, deposit: Double) {
        // Rental fee: (days * price_per_day)
        var days = 1
        if let s = sqlDateFormatter.date(from: req.start_date),
           let e = sqlDateFormatter.date(from: req.end_date) {
            days = max(1, Int(ceil(e.timeIntervalSince(s) / 86400.0)))
        }
        let pricePerDay = req.items?.price_per_day ?? 0
        let rentalFee = Double(days) * pricePerDay

        // Deposit: fetch from items.deposit_amount
        var depositAmount: Double = 0
        do {
            struct DepositDTO: Decodable { let deposit_amount: Double }
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("deposit_amount")
                .eq("id", value: req.item_id)
                .single()
                .execute()
            if let data = response.data as? Data {
                let dto = try JSONDecoder().decode(DepositDTO.self, from: data)
                depositAmount = dto.deposit_amount
            }
        } catch {
            depositAmount = 0
        }
        return (rentalFee, depositAmount)
    }

    private func updateAmountLabels(rental: Double, deposit: Double, total: Double) {
        let rentalText = currencyFormatter.string(from: NSNumber(value: rental)) ?? String(format: "%.2f", rental)
        let depositText = currencyFormatter.string(from: NSNumber(value: deposit)) ?? String(format: "%.2f", deposit)
        let totalText = currencyFormatter.string(from: NSNumber(value: total)) ?? String(format: "%.2f", total)

        fee?.text = rentalText                 // Rental total fee
        seclabel?.text = depositText           // Security Deposit
        totamountlabel?.text = totalText       // Total = rental + deposit
    }

    // MARK: - Owner resolution

    private struct UsersDTO: Decodable {
        let id: String
        let full_name: String?
        let profile_photo_url: String?
    }
    private struct ProfilesDTO: Decodable {
        let full_name: String?
        let avatar_url: String?
    }

    private func fetchAndDisplayOwnerUnified(for ownerId: String) async {
        do {
            let client = SupabaseManager.shared.client

            if let usersData = try? await client
                .from("users")
                .select("id,full_name,profile_photo_url")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                let dto = try JSONDecoder().decode(UsersDTO.self, from: usersData)
                await MainActor.run { [weak self] in
                    self?.renderOwner(fullName: dto.full_name, avatarURLString: dto.profile_photo_url)
                }
                return
            }

            if let profilesData = try? await client
                .from("profiles")
                .select("full_name,avatar_url")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                let dto = try JSONDecoder().decode(ProfilesDTO.self, from: profilesData)
                await MainActor.run { [weak self] in
                    self?.renderOwner(fullName: dto.full_name, avatarURLString: dto.avatar_url)
                }
                return
            }

            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: "Owner", avatarURLString: nil)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: "Owner", avatarURLString: nil)
            }
        }
    }

    private func renderOwner(fullName: String?, avatarURLString: String?) {
        let name = (fullName?.isEmpty == false) ? fullName! : "Owner"
        ownNameLabel?.text = name

        if let avatar = avatarURLString, !avatar.isEmpty, let url = urlForAvatarPath(avatar) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    if let img = img {
                        self?.ownerProfileImage?.image = img
                        self?.ownerProfileImage?.contentMode = .scaleAspectFill
                        self?.ownerProfileImage?.clipsToBounds = true
                        self?.ownerProfileImage?.layer.cornerRadius = (self?.ownerProfileImage?.bounds.height ?? 0) / 2
                        self?.ownerProfileImage?.layer.masksToBounds = true
                    } else {
                        self?.renderOwnerInitials(fullName: name)
                    }
                }
            }
        } else {
            renderOwnerInitials(fullName: name)
        }
    }

    private func renderOwnerInitials(fullName: String) {
        let initials = makeInitials(from: fullName)
        let size = ownerProfileImage?.bounds.size == .zero || ownerProfileImage == nil
            ? CGSize(width: 60, height: 60)
            : ownerProfileImage!.bounds.size

        ownerProfileImage?.image = drawInitialsImage(initials: initials, size: size)
        ownerProfileImage?.contentMode = .scaleAspectFill
        ownerProfileImage?.clipsToBounds = true
        ownerProfileImage?.layer.cornerRadius = (ownerProfileImage?.bounds.height ?? 0) / 2
        ownerProfileImage?.layer.masksToBounds = true
        ownerProfileImage?.backgroundColor = .clear
    }

    private func makeInitials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let first = parts.first?.first.map { String($0).uppercased() } ?? ""
        let last = parts.dropFirst().last?.first.map { String($0).uppercased() } ?? ""
        let combined = first + last
        return combined.isEmpty ? "?" : combined
    }

    private func drawInitialsImage(initials: String, size: CGSize) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(ovalIn: rect).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.4, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let textSize = (initials as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2.0,
                y: (size.height - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            (initials as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    private func urlForAvatarPath(_ path: String) -> URL? {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path)
        } else {
            return StorageURLBuilder.publicFileURL(for: path)
        }
    }

    // Optional: audit event writer
    /*
    private func insertPaymentEvent(type: String, message: String?) async throws {
        guard let paymentId = currentPayment?.id else { return }
        let event = PaymentEventInsert(payment_id: paymentId, event_type: type, raw_payload: message)
        _ = try await SupabaseManager.shared.client
            .from("payment_events")
            .insert(event)
            .execute()
    }
    */

    // MARK: - Tab bar visibility helpers

    private func ensureTabBarHiddenIfNeeded() {
        // If we are pushed in a nav inside a tab bar, hidesBottomBarWhenPushed will work.
        // If not (e.g., SwiftUI-hosted or modally presented over a root tab), hide tab bar manually.
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
        // Walk up the parent/presenting chain to find a UITabBarController
        var parentVC: UIViewController? = self
        while let current = parentVC {
            if let tab = current as? UITabBarController { return tab }
            if let tab = current.tabBarController { return tab }
            parentVC = current.parent ?? current.presentingViewController ?? current.navigationController
        }
        // As a fallback, try the key window’s root
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let tab = window.rootViewController as? UITabBarController {
            return tab
        }
        return nil
    }
}

// MARK: - Glass effect fallback
extension UIView {
    @objc func applyGlassEffectSimple() {
        self.backgroundColor = self.backgroundColor?.withAlphaComponent(0.5) ?? UIColor.systemBackground.withAlphaComponent(0.3)
        self.layer.cornerRadius = self.layer.cornerRadius == 0 ? 16 : self.layer.cornerRadius
        self.layer.masksToBounds = true
    }
}

