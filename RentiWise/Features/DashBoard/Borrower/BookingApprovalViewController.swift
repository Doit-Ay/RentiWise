//  BookingApprovalViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit
import Supabase
import CoreLocation

class BookingApprovalViewController: UIViewController {

    enum RequestStatus {
        case approved
        case pending
    }

    enum PresentationMode {
        case myRentals   // existing behavior
        case history     // no payment UI; show borrower address
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

    // Screen mode: set this before presenting from History
    var mode: PresentationMode = .myRentals {
        didSet {
            if isViewLoaded {
                applyModeUI()
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
    @IBOutlet weak var code6Label: UILabel! // ADDED missing outlet
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
    
    @IBOutlet weak var addressBG: UIView!
    @IBOutlet weak var fee: UILabel!
    @IBOutlet weak var seclabel: UILabel!
    @IBOutlet weak var totamountlabel: UILabel!
    @IBOutlet weak var tickimage: UIImageView!
    @IBOutlet weak var approvedpending: UILabel!
    
    @IBOutlet weak var paymentStatus: UILabel!
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

        // Address label: allow full multi-line text without ellipses
        addressLabel.numberOfLines = 0
        addressLabel.lineBreakMode = .byWordWrapping

        // Start in Pending state and disable payment until accepted
        status = .pending
        paymentButton.isEnabled = false
        paymentButton.alpha = 0.5

        // Initialize status UI based on current status
        updateStatusUI()

        // Reflect any pre-configured dates
        updateDatesUI()

        // Apply current mode (may hide sections)
        applyModeUI()

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

        // Ensure wrapping uses the current width for intrinsic sizing
        addressLabel.preferredMaxLayoutWidth = addressLabel.bounds.width
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Redundantly ensure this VC hides bottom bar when pushed
        hidesBottomBarWhenPushed = true

        // If we’re not pushed in a nav that hides the tab bar, hide tab bar manually (covers SwiftUI-hosted path)
        ensureTabBarHiddenIfNeeded()

        // Extra defensive: if we can find a tab bar controller, force hide its tab bar
        if let tab = findTabBarController() {
            tab.tabBar.isHidden = true
            didHideTabBarManually = true
        }

        updateDatesUI()

        if approvalObserver == nil {
            approvalObserver = NotificationCenter.default.addObserver(forName: BookingApprovalViewController.requestApprovedNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                print("[BookingApproval] Notification received: requestApprovedNotification")
                self.setStatus(.approved)
            }
        }
        if requestsRefreshObserver == nil {
            // Use block-based observer to get a token (previous selector-based returns Void)
            requestsRefreshObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("requestsShouldRefresh"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleRequestsShouldRefresh()
            }
        }

        Task {
            await refreshRequestFromDBIfPossible()
            // Skip payment refresh in history mode for payment button/code, but we will still update label
            if mode == .myRentals {
                await refreshPaymentFromDB()
            } else {
                await refreshPaymentStatusForHistory()
            }
        }
    }

    @objc private func handleRequestsShouldRefresh() {
        print("[BookingApproval] Notification received: requestsShouldRefresh -> marking Approved")
        setStatus(.approved)
        Task { await refreshRequestFromDBIfPossible() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-assert hiding in case a parent made it visible during transition
        ensureTabBarHiddenIfNeeded()
        if let tab = findTabBarController() {
            tab.tabBar.isHidden = true
            didHideTabBarManually = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Only restore the tab bar if this screen is actually leaving (popped/dismissed),
        // not when presenting another controller (like Chat) over it.
        if isMovingFromParent || isBeingDismissed {
            restoreTabBarIfNeeded()
        }

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
        guard let req = self.request else { return }

        // Choose the "other" participant strictly by screen mode:
        // - My Rentals: borrower chatting with owner
        // - History: owner chatting with borrower
        let otherUserId: String = (self.mode == .myRentals) ? req.owner_id : req.borrower_id

        // Instantiate the chat thread controller
        let chatVC = ChatThreadViewController()
        chatVC.otherUserId = otherUserId
        chatVC.itemId = req.item_id
        chatVC.title = "Chat"

        // Present full screen to keep tab bar hidden
        let nav = UINavigationController(rootViewController: chatVC)
        nav.modalPresentationStyle = .fullScreen
        self.present(nav, animated: true)
    }

    @IBAction func openChatButtonTapped(_ sender: Any) {
        openChat()
    }
    
    @IBAction func paymentbuttontapped(_ sender: UIButton) {
        guard mode == .myRentals else { return } // no payment in history
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

    private func applyModeUI() {
        // Hide payment controls and code UI entirely in history mode
        let hidePayment = (mode == .history)

        paymentButton.isHidden = hidePayment
        paymentButton.isEnabled = hidePayment ? false : paymentButton.isEnabled

        viewCodeUIView.isHidden = true // never show code section in history
        viewCodeHeight?.constant = hidePayment ? 0 : viewCodeHeight?.constant ?? 0
        viewCodeHeight?.isActive = true
        statusToViewCodeTop?.constant = 0

        // Also collapse code stack
        codestack.isHidden = true
        codeStackCollapseConstraint?.isActive = true

        // Payment status label visibility
        paymentStatus?.isHidden = (mode == .myRentals)

        // If history, ensure amounts still visible (rent + deposit) but no payment actions
        updateStatusUI()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

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
            // In history mode, keep payment disabled/hidden regardless
            if mode == .myRentals {
                paymentButton.isEnabled = true
                paymentButton.alpha = 1.0
            }
        case .pending:
            approvedpending.text = "Pending"
            tickimage.image = UIImage(systemName: "questionmark.circle.dashed")
            tickimage.tintColor = .white
            paymentButton.isEnabled = false
            paymentButton.alpha = 0.5
        }

        tickimage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        tickimage.contentMode = .scaleAspectFit

        // Show/hide View Code container depending on DB payment status (never show in history)
        let shouldShowCode = hasCompletedPayment && mode == .myRentals
        viewCodeUIView.isHidden = !shouldShowCode
        if shouldShowCode {
            viewCodeHeight?.constant = collapsedViewCodeHeight
            statusToViewCodeTop?.constant = 0
        } else {
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
        }

        // Button title from payment state (ignored if hidden)
        if hasCompletedPayment && mode == .myRentals {
            paymentButton.setTitle("Payment Successful", for: .normal)
            paymentButton.setTitleColor(.black, for: .normal)
            paymentButton.setTitleColor(.black, for: .disabled)
            paymentButton.isEnabled = false
            paymentButton.alpha = 0.6
        } else if mode == .myRentals {
            paymentButton.setTitle("Proceed to Payment", for: .normal)
            paymentButton.setTitleColor(.label, for: .normal)
            paymentButton.setTitleColor(.secondaryLabel, for: .disabled)
            paymentButton.isEnabled = (status == .approved)
            paymentButton.alpha = paymentButton.isEnabled ? 1.0 : 0.5
        }

        // Update payment status label visibility/text per mode
        paymentStatus?.isHidden = (mode == .myRentals)
        if mode == .history {
            updatePaymentStatusLabel()
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
            categoryitemLabel?.text = ""
        }

        // Name/avatar:
        // - My Rentals: show the owner (item owner)
        // - History: show the borrower (person who wants the item)
        Task { [weak self] in
            guard let self = self else { return }
            let userIdToShowName = (self.mode == .history) ? req.borrower_id : req.owner_id
            await self.fetchAndDisplayOwnerUnified(for: userIdToShowName)
        }

        // Address:
        // - My Rentals: show owner address
        // - History: show borrower address (person who wants the item)
        Task { [weak self] in
            guard let self = self else { return }
            let userIdForAddress = (self.mode == .history) ? req.borrower_id : req.owner_id
            await self.fetchAndDisplayAddress(for: userIdForAddress)
        }

        // Update amount labels for the current request
        Task { [weak self] in
            guard let self = self, let req = self.request else { return }
            let amounts = await self.computeAmounts(for: req)
            await MainActor.run {
                self.updateAmountLabels(rental: amounts.rentalFee, deposit: amounts.deposit, total: amounts.rentalFee + amounts.deposit)
            }
        }

        // Only for myRentals, reflect latest payment from DB
        if mode == .myRentals {
            Task { await self.refreshPaymentFromDB() }
        } else {
            // In history, ensure code/flags are reset and update payment status label
            hasCompletedPayment = false
            currentPayment = nil
            setCodeDigits(from: "000000")
            updateStatusUI()
            Task { await self.refreshPaymentStatusForHistory() }
        }
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

    // MARK: - Address (generic)

    private struct OwnerAddressRow: Decodable {
        let address_line1: String
        let address_line2: String?
        let city: String
        let state: String
        let postal_code: String
        let country: String
        let is_default: Bool
        let created_at: String?
    }

    private struct OwnerDefaultAddressRow: Decodable {
        let user_id: String
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
        let is_default: Bool?
        let created_at: String?
    }

    private func formatFullAddress(line1: String, line2: String?, city: String, state: String, postal: String, country: String) -> String {
        let parts: [String] = [
            line1.trimmingCharacters(in: .whitespacesAndNewlines),
            (line2 ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            state.trimmingCharacters(in: .whitespacesAndNewlines),
            postal.trimmingCharacters(in: .whitespacesAndNewlines),
            country.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    private func fetchAndDisplayAddress(for userId: String) async {
        await MainActor.run { self.addressLabel?.text = nil }
        do {
            let client = SupabaseManager.shared.client

            if let data = try? await client
                .from("addresses")
                .select("address_line1,address_line2,city,state,postal_code,country,is_default,created_at")
                .eq("user_id", value: userId)
                .eq("is_default", value: true)
                .single()
                .execute()
                .data as? Data {
                let row = try JSONDecoder().decode(OwnerAddressRow.self, from: data)
                let full = formatFullAddress(line1: row.address_line1, line2: row.address_line2, city: row.city, state: row.state, postal: row.postal_code, country: row.country)
                await MainActor.run { self.addressLabel?.text = full }
                return
            }

            if let data = try? await client
                .from("addresses")
                .select("address_line1,address_line2,city,state,postal_code,country,is_default,created_at")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .single()
                .execute()
                .data as? Data {
                let row = try JSONDecoder().decode(OwnerAddressRow.self, from: data)
                let full = formatFullAddress(line1: row.address_line1, line2: row.address_line2, city: row.city, state: row.state, postal: row.postal_code, country: row.country)
                await MainActor.run { self.addressLabel?.text = full }
                return
            }
        } catch {
            // continue to fallback
        }

        do {
            let client = SupabaseManager.shared.client
            let response = try await client
                .from("user_default_address")
                .select("user_id,latitude,longitude,city,state,country,is_default,created_at")
                .eq("user_id", value: userId)
                .single()
                .execute()

            if let data = response.data as? Data {
                let row = try JSONDecoder().decode(OwnerDefaultAddressRow.self, from: data)

                let parts = [row.city, row.state, row.country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let compact = parts.isEmpty ? nil : parts.joined(separator: ", ")

                if let compact {
                    await MainActor.run { self.addressLabel?.text = compact }
                    return
                }

                if let lat = row.latitude, let lon = row.longitude {
                    let display = await reverseGeocodeIfNeeded(lat: lat, lon: lon, fallbackText: "Address unavailable")
                    await MainActor.run { self.addressLabel?.text = display }
                    return
                }
            }

            await MainActor.run { self.addressLabel?.text = "Address unavailable" }
        } catch {
            await MainActor.run { self.addressLabel?.text = "Address unavailable" }
        }
    }

    private func reverseGeocodeIfNeeded(lat: Double, lon: Double, fallbackText: String) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                let streetNumber = p.subThoroughfare
                let street = p.thoroughfare
                let subLocality = p.subLocality
                let locality = p.locality
                let admin = p.administrativeArea ?? p.subAdministrativeArea
                let postal = p.postalCode
                let country = p.country

                let streetLine: String? = {
                    if let street = street, !street.isEmpty {
                        if let num = streetNumber, !num.isEmpty {
                            return "\(num) \(street)"
                        }
                        return street
                    }
                    return nil
                }()

                let parts = [streetLine, subLocality, locality, admin, postal, country]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                if !parts.isEmpty { return parts.joined(separator: ", ") }
                if let name = p.name, !name.isEmpty { return name }
            }
        } catch {
            // ignore and return fallback
        }
        return fallbackText
    }

    // MARK: - Payments (DB-driven)

    private func refreshPaymentFromDB() async {
        guard mode == .myRentals else { return } // never do in history
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
                    self.updateAmountLabels(rental: p.rental_fee, deposit: p.deposit_amount, total: p.total_amount)
                } else {
                    self.hasCompletedPayment = false
                    self.setCodeDigits(from: "000000")
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

    private func refreshPaymentStatusForHistory() async {
        guard mode == .history, let req = request else { return }
        do {
            let response = try await SupabaseManager.shared.client
                .from("payments")
                .select("status")
                .eq("request_id", value: req.id)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            let decoder = JSONDecoder()
            struct StatusRow: Decodable { let status: String }
            let rows = try decoder.decode([StatusRow].self, from: response.data)
            let latestStatus = rows.first?.status.lowercased()
            await MainActor.run {
                if let latestStatus = latestStatus {
                    if latestStatus == "succeeded" {
                        self.paymentStatus?.text = "Payment Successful"
                        self.paymentStatus?.textColor = .systemGreen
                    } else {
                        self.paymentStatus?.text = "Payment Pending"
                        self.paymentStatus?.textColor = .secondaryLabel
                    }
                } else {
                    self.paymentStatus?.text = "No Payment"
                    self.paymentStatus?.textColor = .secondaryLabel
                }
                self.paymentStatus?.isHidden = (self.mode == .myRentals)
            }
        } catch {
            await MainActor.run {
                self.paymentStatus?.text = "No Payment"
                self.paymentStatus?.textColor = .secondaryLabel
                self.paymentStatus?.isHidden = (self.mode == .myRentals)
            }
        }
    }

    private func performDBBackedPayment(for req: RequestWithItem, provider: String, button: UIButton) async {
        guard mode == .myRentals else { return }
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

        await refreshPaymentFromDB()
        if let p = currentPayment, p.status.lowercased() == "succeeded" {
            await MainActor.run {
                self.updateStatusUI()
            }
            return
        }

        let amounts = await computeAmounts(for: req)
        let rentalFee = amounts.rentalFee
        let deposit = amounts.deposit
        let total = rentalFee + deposit

        await MainActor.run {
            self.updateAmountLabels(rental: rentalFee, deposit: deposit, total: total)
        }

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
        } catch {
            await MainActor.run {
                let ac = UIAlertController(title: "Payment Failed", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
            }
            return
        }

        let code = generatePickupCode()
        let update = PaymentUpdate(status: "succeeded", pickup_code: code, provider_payment_id: nil, provider_receipt_url: nil, failure_reason: nil)

        do {
            _ = try await SupabaseManager.shared.client
                .from("payments")
                .update(update)
                .eq("request_id", value: req.id)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
        } catch {
            await MainActor.run {
                let ac = UIAlertController(title: "Finalize Failed", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
            }
            return
        }

        await refreshPaymentFromDB()
    }

    private func computeAmounts(for req: RequestWithItem) async -> (rentalFee: Double, deposit: Double) {
        var days = 1
        if let s = sqlDateFormatter.date(from: req.start_date),
           let e = sqlDateFormatter.date(from: req.end_date) {
            days = max(1, Int(ceil(e.timeIntervalSince(s) / 86400.0)))
        }
        let pricePerDay = req.items?.price_per_day ?? 0
        let rentalFee = Double(days) * pricePerDay

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

        fee?.text = rentalText
        seclabel?.text = depositText
        totamountlabel?.text = totalText
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

    // MARK: - Payment status label helper

    private func updatePaymentStatusLabel() {
        guard mode == .history else {
            paymentStatus?.isHidden = true
            return
        }
        if let p = currentPayment {
            if p.status.lowercased() == "succeeded" {
                paymentStatus?.text = "Payment Successful"
                paymentStatus?.textColor = .systemGreen
            } else {
                paymentStatus?.text = "Payment Pending"
                paymentStatus?.textColor = .secondaryLabel
            }
        } else {
            if paymentStatus?.text?.isEmpty ?? true {
                paymentStatus?.text = "No Payment"
                paymentStatus?.textColor = .secondaryLabel
            }
        }
        paymentStatus?.isHidden = false
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
