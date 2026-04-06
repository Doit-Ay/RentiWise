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
        case cancelled
        case rejected
        case completed
    }

    enum PresentationMode {
        case myRentals   // existing behavior
        case history     // no payment UI; show borrower address
    }

    nonisolated static let requestApprovedNotification = Notification.Name("BookingApprovalRequestApprovedNotification")
    nonisolated static let requestCancelledNotification = Notification.Name("BookingApprovalRequestCancelledNotification")

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
            debugLog("[BookingApproval] Status changed to: \(status)")
            updateStatusUI()
        }
    }

    // Booking dates passed from RequestViewController or mapped from request
    private var startDate: Date?
    private var pickupTime: Date?
    private var returnTime: Date?

    // Removed payment related properties:
    // private var hasCompletedPayment: Bool = false
    // private var currentPayment: PaymentRow?

    // Observer token to manage notification observer lifecycle
    private var approvalObserver: NSObjectProtocol?
    private var requestsRefreshObserver: NSObjectProtocol?

    // IBOutlets
    
    @IBOutlet weak var getdirectionbutton: UIButton!
    @IBOutlet weak var copybutton: UIButton!
    @IBOutlet weak var chatButton: UIButton!
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
    
    // Extend and Return buttons (borrower only)
    @IBOutlet weak var extendButton: UIButton!
    @IBOutlet weak var returnButton: UIButton!
    @IBOutlet weak var extendReturnButtonsStack: UIStackView!
    
    // Status labels for return/extend requests (created programmatically)
    private var returnStatusLabel: UILabel?
    private var extensionStatusLabel: UILabel?
    
    
    // Track current request statuses
    private var currentReturnRequestStatus: String?
    private var currentExtensionRequestStatus: String?
    private var currentReturnRequestId: String?
    private var currentExtensionRequestId: String?
    private var rentalPaymentState = RentalPaymentState.empty

    
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

    // Heights
    private let collapsedViewCodeHeight: CGFloat = 56
    private let expandedViewCodeHeight: CGFloat = 140

    // Formatters for mapping DB strings to Date
    private lazy var sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
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

    // Prevents re-running the full data load on every viewDidAppear.
    private var hasLoadedInitialData = false

    // Periodic refresh timer — polls for status changes while on screen
    private var refreshTimer: Timer?
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
    private let statusWarningColor = UIColor(red: 0xBD/255.0, green: 0x83/255.0, blue: 0x2F/255.0, alpha: 1)
    private var loadingOverlay: UIView?
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()

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

        // Start collapsed: show only the button, hide the stack
        codestack.isHidden = true
        // Hide code view initially and collapse its height/spacing
        viewCodeUIView.isHidden = true
        viewCodeHeight?.constant = 0
        viewCodeHeight?.isActive = true
        statusToViewCodeTop?.constant = 0

        // Style buttons
        [paymentButton, getdirectionbutton, copybutton].forEach {
            $0?.layer.borderColor = UIColor.black.cgColor
            $0?.layer.borderWidth = 0
            $0?.layer.cornerRadius = 8
            $0?.layer.masksToBounds = true
        }
        paymentButton.configuration = nil
        paymentButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        paymentButton.contentHorizontalAlignment = .center
        paymentStatus?.numberOfLines = 0
        paymentStatus?.lineBreakMode = .byWordWrapping
        paymentStatus?.lineBreakMode = .byWordWrapping

        // Style Extend & Return buttons: no SF symbols, height 44, 18pt semibold
        for btn in [extendButton, returnButton] {
            guard let b = btn else { continue }
            // Clear any UIButton.Configuration that overrides traditional APIs
            b.configuration = nil
            b.setImage(nil, for: .normal)
            b.imageView?.image = nil
            b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            b.layer.cornerRadius = 8
            b.layer.masksToBounds = true
            // Remove any existing height constraints and add 44pt
            for c in b.constraints where c.firstAttribute == .height {
                c.isActive = false
            }
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }

        // Ensure owner image is circular
        ownerProfileImage?.clipsToBounds = true
        ownerProfileImage?.contentMode = .scaleAspectFill
        ownNameLabel?.numberOfLines = 2
        ownNameLabel?.lineBreakMode = .byTruncatingTail

        // Round product image corners
        imageprod?.clipsToBounds = true
        imageprod?.layer.cornerRadius = 16

        setupLoadingOverlay()

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
        
        // Setup request status labels programmatically
        setupRequestStatusLabels()

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

        if let overlay = loadingOverlay, !overlay.isHidden {
            view.bringSubviewToFront(overlay)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Redundantly ensure this VC hides bottom bar when pushed
        hidesBottomBarWhenPushed = true


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
                debugLog("[BookingApproval] Notification received: requestApprovedNotification")
                Task {
                    await self.refreshRequestFromDBIfPossible()
                    await self.refreshRentalPaymentState()
                    await self.fetchRequestStatuses()
                }
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

        // NOTE: DB refresh tasks are started in viewDidAppear (after push animation completes)
        // to avoid main-thread dispatches during the push transition causing animation jank.

    }

    @objc private func handleRequestsShouldRefresh() {
        debugLog("[BookingApproval] Notification received: requestsShouldRefresh -> refreshing request")
        Task {
            await refreshRequestFromDBIfPossible()
            await refreshRentalPaymentState()
            await fetchRequestStatuses()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-assert hiding in case a parent made it visible during transition
        ensureTabBarHiddenIfNeeded()
        if let tab = findTabBarController() {
            tab.tabBar.isHidden = true
            didHideTabBarManually = true
        }

        // On subsequent appearances (e.g. returning from a modal or child VC),
        // only refresh the request row and button statuses — skip the full reload.
        guard !hasLoadedInitialData else {
            Task { [weak self] in
                await self?.refreshRequestFromDBIfPossible()
                await self?.refreshRentalPaymentState()
                await self?.fetchRequestStatuses()
            }
            startRefreshTimer() // Restart polling when returning from a modal/child VC
            return
        }
        hasLoadedInitialData = true

        // Start ALL network-dependent data here — AFTER the push animation completes.
        // applyRequestToUI() only sets lightweight UI (text/status) from already-loaded request.
        // Everything requiring a network call is deferred to here.
        Task { [weak self] in
            guard let self, let req = self.request else { return }
            await MainActor.run {
                self.setLoading(true, message: "Loading booking details...")
            }
            let isHistoryMode = await MainActor.run { self.mode == .history }

            // Execute network requests completely in parallel to reduce loading latency
            async let reqRefreshTask: Void = self.refreshRequestFromDBIfPossible()
            async let payRefreshTask: Void = self.refreshRentalPaymentState()
            
            async let ownerTask: Void = {
                let userIdToShow = isHistoryMode ? req.borrower_id : req.owner_id
                await self.fetchAndDisplayOwnerUnified(for: userIdToShow)
            }()
            
            async let addressTask: Void = {
                let userIdForAddress = isHistoryMode ? req.borrower_id : req.owner_id
                if isHistoryMode {
                    await self.fetchAndDisplayAddress(for: userIdForAddress)
                } else {
                    // Start address check assuming status might be accepted based on current req state
                    // The address fetch handles missing data nicely anyway
                    let rawStatus = req.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let isAccepted = ["accepted", "approved", "pickup_verified", "active", "completed"].contains(rawStatus)
                    if isAccepted {
                        await self.fetchAndDisplayAddress(for: userIdForAddress)
                    }
                }
            }()
            
            async let amountsTask: Void = {
                let amounts = await self.computeAmounts(for: req)
                await MainActor.run {
                    self.updateAmountLabels(rental: amounts.rentalFee, deposit: 0, total: amounts.rentalFee)
                }
            }()
            
            // Wait for all concurrently running tasks
            _ = await (reqRefreshTask, payRefreshTask, ownerTask, addressTask, amountsTask)
            
            await fetchRequestStatuses()

            // Start periodic refresh after initial load completes
            await MainActor.run {
                self.setLoading(false)
                self.startRefreshTimer()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop periodic refresh when leaving the screen
        refreshTimer?.invalidate()
        refreshTimer = nil

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

    // MARK: - Periodic Refresh

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.performPeriodicRefresh()
        }
    }

    /// Lightweight refresh that polls DB for status changes while the screen is visible.
    private func performPeriodicRefresh() {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshRequestFromDBIfPossible()
            await self.refreshRentalPaymentState()
            await self.fetchRequestStatuses()
        }
    }

    func configureDates(startDate: Date?, pickupTime: Date?, returnTime: Date?) {
        self.startDate = startDate
        self.pickupTime = pickupTime
        self.returnTime = returnTime
        updateDatesUI()
    }
    
    // MARK: - Request Status Management
    
    /// Fetch the latest status for return and extension requests
    private func fetchRequestStatuses() async {
        guard let bookingId = request?.id else { return }
        
        // Fetch return request status
        await fetchReturnRequestStatus(for: bookingId)
        
        // Fetch extension request status
        await fetchExtensionRequestStatus(for: bookingId)
        
        // Update UI on main thread
        await MainActor.run {
            updateReturnButtonState()
            updateExtensionButtonState()
        }
    }
    
    private func fetchReturnRequestStatus(for bookingId: String) async {
        do {
            struct ReturnRequestRow: Decodable {
                let id: String
                let status: String
            }
            
            let response = try await SupabaseManager.shared.client
                .from("return_requests")
                .select("id, status")
                .eq("request_id", value: bookingId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            let data = response.data
            let requests = try JSONDecoder().decode([ReturnRequestRow].self, from: data)
            
            if let latestRequest = requests.first {
                currentReturnRequestId = latestRequest.id
                currentReturnRequestStatus = latestRequest.status
                debugLog("[BookingApproval] Return request status: \(latestRequest.status)")
            } else {
                currentReturnRequestId = nil
                currentReturnRequestStatus = nil
            }
        } catch {
            debugLog("[BookingApproval] Error fetching return request status: \(error)")
            currentReturnRequestStatus = nil
        }
    }
    
    private func fetchExtensionRequestStatus(for bookingId: String) async {
        do {
            struct ExtensionRequestRow: Decodable {
                let id: String
                let status: String
            }
            
            let response = try await SupabaseManager.shared.client
                .from("extension_requests")
                .select("id, status")
                .eq("request_id", value: bookingId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            let data = response.data
            let requests = try JSONDecoder().decode([ExtensionRequestRow].self, from: data)
            
            if let latestRequest = requests.first {
                currentExtensionRequestId = latestRequest.id
                currentExtensionRequestStatus = latestRequest.status
                debugLog("[BookingApproval] Extension request status: \(latestRequest.status)")
                
                // Show notification to borrower if accepted — only once per extension request
                let alertKey = "extensionAlertShown_\(latestRequest.id)"
                if latestRequest.status == "accepted" && self.mode == .myRentals && !UserDefaults.standard.bool(forKey: alertKey) {
                    UserDefaults.standard.set(true, forKey: alertKey)
                    await MainActor.run {
                        let borrowerName = UserDefaults.standard.string(forKey: "user_full_name") ?? "You"
                        let msg = "Extension request for - \(borrowerName) accepted"
                        let alert = UIAlertController(title: "Extension Accepted", message: msg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            } else {
                currentExtensionRequestId = nil
                currentExtensionRequestStatus = nil
            }
        } catch {
            debugLog("[BookingApproval] Error fetching extension request status: \(error)")
            currentExtensionRequestStatus = nil
        }
    }
    
    private func updateReturnButtonState() {
        guard status != .completed else { return }

        // Clear any attributed title set in Storyboard so setTitle(_:for:) works
        returnButton?.setAttributedTitle(nil, for: .normal)
        returnButton?.setTitleColor(.white, for: .normal)
        let rentalStatus = request?.rentalStatus ?? .pending
        let fallbackTitle = rentalStatus.borrowerPrimaryActionTitle ?? "Return Item"
        let fallbackBackgroundColor: UIColor = rentalStatus.borrowerPrimaryActionIsDestructive
            ? .systemRed
            : UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
        
        // CROSS-DISABLE: If an extension is pending, you cannot return yet
        // (Once extension is accepted, both buttons re-enable so user can extend again or return)
        if currentExtensionRequestStatus == "pending" {
            returnButton?.setTitle(fallbackTitle, for: .normal)
            returnButton?.isEnabled = false
            returnButton?.alpha = 0.5
            returnStatusLabel?.isHidden = true
            return
        }
        
        if let status = currentReturnRequestStatus {
            returnStatusLabel?.isHidden = false
            if let lbl = returnStatusLabel { styleStatusLabel(lbl, status: status, isExtension: false) }
            
            switch status {
            case "pending":
                returnButton?.setTitle("Cancel Return", for: .normal)
                returnButton?.backgroundColor = .systemRed
                returnButton?.isEnabled = true
                returnButton?.alpha = 1.0
            case "rejected":
                returnButton?.setTitle(fallbackTitle, for: .normal)
                returnButton?.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
                returnButton?.isEnabled = true
                returnButton?.alpha = 1.0
            case "accepted":
                returnButton?.setTitle("Verify Return", for: .normal)
                returnButton?.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
                returnButton?.isEnabled = true
                returnButton?.alpha = 1.0
            default:
                returnButton?.setTitle(fallbackTitle, for: .normal)
                returnButton?.backgroundColor = fallbackBackgroundColor
                returnButton?.isEnabled = true
                returnButton?.alpha = 1.0
            }
        } else {
            returnStatusLabel?.isHidden = true
            returnButton?.setTitle(fallbackTitle, for: .normal)
            returnButton?.backgroundColor = fallbackBackgroundColor
            returnButton?.isEnabled = true
            returnButton?.alpha = 1.0
        }
    }
    
    private func updateExtensionButtonState() {
        if status == .completed || status == .cancelled || status == .rejected {
            extensionStatusLabel?.isHidden = true
            return
        }
        
        // If the extend button is hidden (meaning the current state doesn't allow extending),
        // we should also hide the note/status label.
        if extendButton?.isHidden == true || extendReturnButtonsStack?.isHidden == true || mode == .history {
            extensionStatusLabel?.isHidden = true
            return
        }

        // Clear any attributed title set in Storyboard so setTitle(_:for:) works
        extendButton?.setAttributedTitle(nil, for: .normal)
        extendButton?.setTitleColor(.white, for: .normal)

        // CROSS-DISABLE: If a return handoff is in progress, extending is not allowed.
        if currentReturnRequestStatus == "pending" || currentReturnRequestStatus == "accepted" {
            extendButton?.setTitle("Extend Rental", for: .normal)
            extendButton?.isEnabled = false
            extendButton?.alpha = 0.5
            extensionStatusLabel?.isHidden = true
            return
        }
        
        if let status = currentExtensionRequestStatus {
            extensionStatusLabel?.isHidden = false
            if let lbl = extensionStatusLabel { styleStatusLabel(lbl, status: status, isExtension: true) }
            
            // Disable extend button forever if a request is pending, accepted, or rejected.
            extendButton?.setTitle("Extend Rental", for: .normal)
            extendButton?.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
            extendButton?.isEnabled = false
            extendButton?.alpha = 0.5
        } else {
            // No request exists, active "Extend Rental" functionality.
            extensionStatusLabel?.isHidden = false
            extensionStatusLabel?.text = "Note: Extension can only be requested once"
            extensionStatusLabel?.textColor = .secondaryLabel
            extensionStatusLabel?.font = .systemFont(ofSize: 12, weight: .regular)
            
            extendButton?.setTitle("Extend Rental", for: .normal)
            if let teal = extendButton?.backgroundColor, teal == .systemRed {
                extendButton?.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
            }
            extendButton?.isEnabled = true
            extendButton?.alpha = 1.0
        }
    }
    
    private func styleStatusLabel(_ label: UILabel, status: String, isExtension: Bool = false) {
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        switch status.lowercased() {
        case "pending":
            label.text = "Status: Pending"
            label.textColor = .systemOrange
        case "accepted":
            if isExtension {
                label.text = "Status: Request Accepted ✓"
            } else {
                label.text = "Status: Return Approved\nEnter lender code"
            }
            label.textColor = .systemGreen
        case "completed":
            label.text = "Status: Completed ✓"
            label.textColor = .systemGreen
        case "rejected":
            label.text = "Status: Rejected"
            label.textColor = .systemRed
        default:
            label.text = "Status: \(status.capitalized)"
            label.textColor = .secondaryLabel
        }
    }
    
    private func setupRequestStatusLabels() {
        // Only show status labels in myRentals mode (borrower side)
        guard mode == .myRentals else {
            returnStatusLabel?.isHidden = true
            extensionStatusLabel?.isHidden = true
            return
        }
        
        guard let buttonStack = extendReturnButtonsStack,
              let parentView = buttonStack.superview else {
            debugLog("[BookingApproval] Could not find button stack or parent view")
            return
        }
        
        // Create return status label (right side, under return button)
        if returnStatusLabel == nil {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.isHidden = true // Hidden by default
            parentView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: buttonStack.trailingAnchor),
                label.widthAnchor.constraint(equalTo: buttonStack.widthAnchor, multiplier: 0.48)
            ])
            
            returnStatusLabel = label
        }
        
        // Create extension status label (left side, under extend button)
        if extensionStatusLabel == nil {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.isHidden = true // Hidden by default
            parentView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: buttonStack.leadingAnchor),
                label.widthAnchor.constraint(equalTo: buttonStack.widthAnchor, multiplier: 0.48)
            ])
            
            extensionStatusLabel = label
        }
    }






    func didSelectNewProductFromMyRentals() {
        // Removed payment reset logic
        viewCodeUIView.isHidden = true
        statusToViewCodeTop?.constant = 16
        paymentButton.setTitle("Pay via UPI", for: .normal)
        updateStatusUI()
    }

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        // Borrower cannot accept here; status comes from owner and DB.
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        // Borrower cannot deny here; status comes from owner and DB.
    }

    // Centralized chat opener that derives the correct mode and passes the right parameters.
    private func openChatSafely() {
        guard let req = self.request else { return }

        Task {
            // Derive role at the moment of opening to avoid stale mode
            let me = await SupabaseManager.shared.currentUserId()
            let isOwner = (me?.lowercased() == req.owner_id.lowercased())
            let derivedMode: PresentationMode = isOwner ? .history : .myRentals
            
            debugLog("[BookingApproval] openChatSafely - me=\(me ?? "nil"), itemOwnerId=\(req.owner_id), borrowerId=\(req.borrower_id)")
            debugLog("[BookingApproval] isOwner=\(isOwner), derivedMode=\(derivedMode)")

            await MainActor.run { self.mode = derivedMode }

            // Borrower path: pass only itemId (helper resolves owner as other user)
            if derivedMode == .myRentals {
                debugLog("[BookingApproval] Chat open as borrower. itemId=\(req.item_id)")
                ChatThreadViewController.open(from: self, itemId: req.item_id)
                return
            }

            // Owner path: must pass borrower_id; guard against missing/invalid
            let borrower = req.borrower_id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !borrower.isEmpty, borrower.lowercased() != req.owner_id.lowercased() else {
                debugLog("[BookingApproval] ERROR: Invalid borrower! borrower=\(borrower), owner=\(req.owner_id)")
                let ac = UIAlertController(title: "Chat", message: "Borrower not specified for this item.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                await MainActor.run { self.present(ac, animated: true) }
                return
            }

            debugLog("[BookingApproval] Chat open as owner. itemId=\(req.item_id) borrowerId=\(borrower)")
            ChatThreadViewController.open(from: self, itemId: req.item_id, otherUserId: borrower)
        }
    }

    @objc private func openChat() {
        openChatSafely()
    }

    @IBAction func openChatButtonTapped(_ sender: Any) {
        // Guard: do not open chat if button is disabled (before acceptance)
        if let btn = sender as? UIButton, !btn.isEnabled { return }
        guard mode == .history || status == .approved || status == .completed else {
            showToast(message: "Chat will be enabled when owner accepts your request", fromBottom: false)
            return
        }
        openChatSafely()
    }
    
    @IBAction func ViewHideCodeButton(_ sender: UIButton) {
        if shouldShowPickupOTPCTA && !showsLegacyInlinePickupCode {
            let otpVC = BorrowerOTPViewController()
            otpVC.requestId = request?.id ?? ""
            otpVC.lenderName = ownNameLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (ownNameLabel?.text ?? "Lender")
                : "Lender"
            navigationController?.pushViewController(otpVC, animated: true)
            return
        }

        // Toggle the code stack visibility with animation
        UIView.animate(withDuration: 0.3) {
            let isCurrentlyHidden = self.codestack.isHidden
            
            if isCurrentlyHidden {
                // Expand: show the code stack
                self.codestack.isHidden = false
                self.viewCodeHeight?.constant = self.expandedViewCodeHeight
                sender.setTitle("Hide Code", for: .normal)
            } else {
                // Collapse: hide the code stack
                self.codestack.isHidden = true
                self.viewCodeHeight?.constant = self.collapsedViewCodeHeight
                sender.setTitle("View Code", for: .normal)
            }
            
            self.view.layoutIfNeeded()
        }
    }
    
    // UPI payment flow — borrower pays lender directly via UPI
    @IBAction func paymentbuttontapped(_ sender: UIButton) {
        guard mode == .myRentals else { return }
        guard let req = request else { return }
        Task { [weak self] in
            guard let self else { return }
            struct Profile: Decodable { let full_name: String?; let upi_id: String? }
            var upi = ""
            var lenderName = ownNameLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Lender"
            do {
                let resp = try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .select("full_name, upi_id")
                    .eq("id", value: req.owner_id)
                    .single()
                    .execute()
                if let dto = try? JSONDecoder().decode(Profile.self, from: resp.data) {
                    upi = dto.upi_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if let n = dto.full_name, !n.isEmpty { lenderName = n }
                }
            } catch { }

            let total = await self.computeAmountsForUPI(for: req)
            let durationDays = self.durationDays(for: req)
            let borrowerName = await self.currentUserDisplayName()

            await MainActor.run {
                let vc = UPIConfirmationViewController()
                vc.requestId = req.id
                vc.itemName = req.items?.title ?? "Item"
                vc.itemId = req.item_id
                vc.totalAmount = total
                vc.depositAmount = 0
                vc.lenderUpiId = upi
                vc.lenderName = lenderName
                vc.lenderId = req.owner_id
                vc.borrowerId = req.borrower_id
                vc.borrowerName = borrowerName
                vc.startDate = self.sqlDateFormatter.date(from: req.start_date) ?? Date()
                vc.endDate = self.sqlDateFormatter.date(from: req.end_date) ?? Date()
                vc.durationDays = durationDays
                vc.pricePerDay = req.items?.price_per_day ?? 0
                vc.onPaymentConfirmed = { [weak self] in
                    guard let self else { return }
                    self.showToast(message: "Payment marked as sent", fromBottom: false)
                    NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
                    Task { await self.refreshRentalPaymentState() }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    
    @IBAction func getDirectionsButtonTapped(_ sender: UIButton) {
        // Guard: do not open directions if button is disabled (before acceptance)
        guard sender.isEnabled else { return }
        openDirections()
    }
    
    private func openDirections() {
        // Get the address text from the label
        guard let addressText = addressLabel?.text, !addressText.isEmpty,
              addressText != "Address unavailable",
              !addressText.contains("will be enabled") else {
            showToast(message: "Address not available", fromBottom: false)
            return
        }
        
        let encodedAddress = addressText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps app first, then fallback to Google Maps in browser
        if let googleMapsAppURL = URL(string: "comgooglemaps://?q=\(encodedAddress)"),
           UIApplication.shared.canOpenURL(googleMapsAppURL) {
            UIApplication.shared.open(googleMapsAppURL)
        } else if let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)") {
            UIApplication.shared.open(webURL)
        }
    }
    
    @IBAction func copyAddressButtonTapped(_ sender: UIButton) {
        // Copy the address to clipboard
        guard let addressText = addressLabel?.text, !addressText.isEmpty,
              addressText != "Address unavailable",
              !addressText.contains("will be enabled") else {
            showToast(message: "Address not available", fromBottom: true)
            return
        }
        
        UIPasteboard.general.string = addressText
        
        // Show a brief confirmation with haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Visual feedback: briefly change button appearance
        let originalAlpha = sender.alpha
        UIView.animate(withDuration: 0.15, animations: {
            sender.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                sender.alpha = originalAlpha
            }
        }
        
        // Show bottom toast notification
        showToast(message: "Address copied", fromBottom: true)
    }
    
    @IBAction func extendRentalButtonTapped(_ sender: UIButton) {
        guard let req = request else { return }
        
        let extendVC = ExtendRentalViewController(nibName: "ExtendRentalViewController", bundle: nil)
        extendVC.request = req
        // Build full end date+time using BookingPresentationFormatter to handle
        // DB formats like "04:03:00+05:30" correctly
        if let returnTimeParsed = BookingPresentationFormatter.parseTime(req.return_time),
           let endDateParsed = BookingPresentationFormatter.sqlDateFormatter.date(from: req.end_date) {
            extendVC.originalEndDate = BookingPresentationFormatter.combine(date: endDateParsed, time: returnTimeParsed)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = .current
            extendVC.originalEndDate = dateFormatter.date(from: req.end_date)
        }
        
        // Instantly update button state when request is submitted
        extendVC.onRequestSubmitted = { [weak self] in
            guard let self else { return }
            self.currentExtensionRequestStatus = "pending"
            self.updateExtensionButtonState()
            self.updateReturnButtonState() // Cross-disable the return button
        }
        
        extendVC.modalPresentationStyle = .pageSheet
        if let sheet = extendVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(extendVC, animated: true)
    }
    
    @IBAction func returnItemButtonTapped(_ sender: UIButton) {
        guard let req = request else { return }
        let rentalStatus = req.rentalStatus

        // If return is pending → act as "Cancel Return"
        if currentReturnRequestStatus == "pending" {
            cancelReturnRequest()
            return
        }

        if currentReturnRequestStatus == "accepted" {
            let otpVC = BorrowerReturnOTPInputViewController()
            otpVC.requestId = req.id
            otpVC.onVerified = { [weak self] in
                guard let self else { return }
                self.currentReturnRequestStatus = "completed"
                if var currentRequest = self.request {
                    currentRequest.status = "completed"
                    self.request = currentRequest
                }
                self.status = .completed
                self.updateReturnButtonState()
                self.updateExtensionButtonState()
                NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
            }
            navigationController?.pushViewController(otpVC, animated: true)
            return
        }

        // Before pickup is verified, borrower can only cancel the request.
        if rentalStatus.borrowerCanCancelBeforePickup {
            cancelRequest()
            return
        }

        guard rentalStatus.borrowerShowsExtendAndReturnActions else { return }

        // Approved: open Return Proof flow
        let returnVC = ReturnProofViewController(nibName: "ReturnProofViewController", bundle: nil)
        returnVC.request = req
        
        // Instantly update button state when request is submitted
        returnVC.onRequestSubmitted = { [weak self] in
            guard let self else { return }
            self.currentReturnRequestStatus = "pending"
            self.updateReturnButtonState()
            self.updateExtensionButtonState() // Cross-disable the extend button
        }
        
        returnVC.modalPresentationStyle = .pageSheet
        if let sheet = returnVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(returnVC, animated: true)
    }

    // MARK: - Cancel Request

    private func cancelRequest() {
        let alert = UIAlertController(
            title: "Cancel Request",
            message: "Are you sure you want to cancel this rental request?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes, Cancel", style: .destructive) { [weak self] _ in
            self?.performCancelRequest()
        })
        present(alert, animated: true)
    }

    private func performCancelRequest() {
        guard let reqId = request?.id else { return }
        let previousStatus = request?.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let itemId = request?.item_id

        Task { [weak self] in
            guard let self = self else { return }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("requests")
                    .update(["status": "cancelled"])
                    .eq("id", value: reqId)
                    .execute()

                if (previousStatus == "accepted" || previousStatus == "approved"), let itemId {
                    try? await self.setItemAvailability(itemId: itemId, isActive: true)
                }

                await MainActor.run {
                    // Update local request status
                    self.request?.status = "cancelled"

                    // Update UI live — show cancelled state without navigating away
                    self.setStatus(.cancelled)

                    // Notify My Rentals to update the card status
                    NotificationCenter.default.post(
                        name: BookingApprovalViewController.requestCancelledNotification,
                        object: nil,
                        userInfo: ["requestId": reqId, "status": "cancelled"]
                    )
                    NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)

                    // Track analytics & local notification
                    AnalyticsService.shared.trackRentalEnded(requestId: reqId, status: "cancelled")
                    NotificationService.shared.notifyStatusChange(
                        requestId: reqId,
                        itemTitle: self.request?.items?.title ?? "Item",
                        newStatus: .cancelled,
                        role: "borrower"
                    )
                    NotificationService.shared.cancelNotifications(forRequestId: reqId)
                }
            } catch {
                await MainActor.run {
                    let a = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                }
            }
        }
    }

    private func setItemAvailability(itemId: String, isActive: Bool) async throws {
        struct ItemPatch: Encodable { let is_active: Bool }

        _ = try await SupabaseManager.shared.client
            .from("items")
            .update(ItemPatch(is_active: isActive))
            .eq("id", value: itemId)
            .execute()
    }

    // MARK: - Cancel Return Requests (while pending)

    private func cancelReturnRequest() {
        let alert = UIAlertController(
            title: "Cancel Return Request",
            message: "Are you sure you want to cancel your return request?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes, Cancel", style: .destructive) { [weak self] _ in
            guard let self, let rowId = self.currentReturnRequestId else { return }
            Task {
                do {
                    _ = try await SupabaseManager.shared.client
                        .from("return_requests")
                        .delete()
                        .eq("id", value: rowId)
                        .execute()
                    await MainActor.run {
                        self.currentReturnRequestId = nil
                        self.currentReturnRequestStatus = nil
                        self.updateReturnButtonState()
                        self.updateExtensionButtonState()
                    }
                } catch {
                    await MainActor.run {
                        let a = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Button title based on request status

    private func updateReturnButtonForRequestStatus() {
        // Hide extend/return for terminal states
        if status == .cancelled || status == .rejected || status == .completed {
            extendReturnButtonsStack?.isHidden = true
            return
        }
        
        // Determine the current rental phase from DB status
        let dbStatus = request?.rentalStatus ?? .pending

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]

        // Ensure no SF symbols and clear configuration to prevent overrides
        for btn in [extendButton, returnButton] {
            guard let b = btn else { continue }
            b.configuration = nil
            b.setImage(nil, for: .normal)
            b.imageView?.image = nil
            b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        }
        
        if dbStatus.borrowerCanCancelBeforePickup {
            // Borrower can cancel while the request is pending or accepted, until pickup is verified.
            returnButton?.setAttributedTitle(NSAttributedString(string: "Cancel Request", attributes: attrs), for: .normal)
            returnButton?.backgroundColor = .systemRed
            returnButton?.isHidden = false
            extendButton?.isHidden = true
            extendReturnButtonsStack?.isHidden = false
        } else if dbStatus.borrowerShowsExtendAndReturnActions {
            // Active rental — borrower can extend or return
            returnButton?.setAttributedTitle(NSAttributedString(string: "Return Item", attributes: attrs), for: .normal)
            returnButton?.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1)
            returnButton?.isHidden = false
            extendButton?.setAttributedTitle(NSAttributedString(string: "Extend Rental", attributes: attrs), for: .normal)
            extendButton?.isHidden = false
            extendReturnButtonsStack?.isHidden = false
        } else {
            // Denied or other non-actionable states
            extendReturnButtonsStack?.isHidden = true
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NotificationCenter.default.removeObserver(self, name: BookingApprovalViewController.requestApprovedNotification, object: nil)
    }

    // MARK: - Private helpers

    private func applyModeUI() {
        if mode == .history {
            paymentButton.isHidden = true
            paymentButton.isEnabled = false
            paymentStatus?.isHidden = true
            viewCodeUIView.isHidden = true
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
        }

        // Hide Extend and Return buttons for owners (only show to borrowers)
        let hideExtendReturnButtons = (mode == .history)
        extendReturnButtonsStack?.isHidden = hideExtendReturnButtons

        // Update UI based on current approval status and code availability
        updateStatusUI()
        // Note: do NOT call layoutIfNeeded() here — it forces a
        // synchronous layout pass on the main thread during the push animation.
        view.setNeedsLayout()
    }

    private func updateDatesUI() {
        if let req = request,
           let booking = BookingPresentationFormatter.presentation(
                from: req,
                pricePerDay: req.items?.price_per_day ?? 0
           ) {
            dateperiodLabel.text = booking.dateText
            picktimeLabel.text = booking.timeText
            numLabeldays.text = booking.durationText
            return
        }

        dateperiodLabel.text = startDate.map { BookingPresentationFormatter.displayDateString(for: $0) } ?? ""
        picktimeLabel.text = pickupTime.map { BookingPresentationFormatter.displayTimeString(for: $0) } ?? ""
        numLabeldays.text = ""
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

    private var shouldShowPaymentCTA: Bool {
        guard mode == .myRentals else { return false }
        return request?.rentalStatus == .accepted && !rentalPaymentState.borrowerMarkedPaid
    }

    private var shouldShowPickupOTPCTA: Bool {
        guard mode == .myRentals else { return false }
        return request?.rentalStatus == .accepted && rentalPaymentState.lenderConfirmedReceived
    }

    private var showsLegacyInlinePickupCode: Bool {
        guard mode == .myRentals else { return false }
        let hasLegacyCode = !(request?.pickup_code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let accepted = request?.rentalStatus == .accepted
        return hasLegacyCode && accepted
    }

    private var viewCodePrimaryButton: UIButton? {
        viewCodeUIView?.subviews.compactMap { $0 as? UIButton }.first
    }

    private func refreshPaymentRowVisibility() {
        guard mode == .myRentals else {
            paymentButton.isHidden = true
            paymentButton.isEnabled = false
            paymentButton.alpha = 0.5
            paymentStatus?.isHidden = true
            viewCodeUIView.isHidden = true
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
            return
        }

        let showsPaymentCTA = shouldShowPaymentCTA

        paymentButton.isHidden = !showsPaymentCTA
        paymentButton.isEnabled = showsPaymentCTA
        paymentButton.alpha = showsPaymentCTA ? 1.0 : 0.5

        paymentStatus?.isHidden = showsPaymentCTA

        let shouldShowPickupContainer = shouldShowPickupOTPCTA || showsLegacyInlinePickupCode
        viewCodeUIView.isHidden = !shouldShowPickupContainer

        if shouldShowPickupContainer {
            codestack.isHidden = true
            viewCodeHeight?.constant = collapsedViewCodeHeight
            statusToViewCodeTop?.constant = 0
            viewCodePrimaryButton?.setTitle(
                shouldShowPickupOTPCTA && !showsLegacyInlinePickupCode
                    ? (RequestSchemaSupport.supportsPickupCode ? "View Pickup OTP" : "Pickup Instructions")
                    : "View Code",
                for: .normal
            )
        } else {
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
        }

        if showsPaymentCTA {
            statusView?.bringSubviewToFront(paymentButton)
        } else if let paymentStatus {
            statusView?.bringSubviewToFront(paymentStatus)
        }
    }

    private func updateStatusUI() {
        // circ2 is the teal circle behind the icon — always teal
        circ2?.backgroundColor = brandTeal

        switch status {
        case .approved:
            // Differentiate between "accepted" (awaiting OTP) and "approved" (active rental)
            let dbStatus = request?.rentalStatus ?? .approved
            if dbStatus == .accepted {
                // Lender accepted, awaiting OTP pickup verification
                approvedpending.text = "Accepted"
                approvedpending.textColor = .label
                tickimage.image = UIImage(systemName: "checkmark.circle")
                tickimage.tintColor = .white
            } else {
                // Pickup verified — rental is active
                approvedpending.text = "Active"
                approvedpending.textColor = .label
                tickimage.image = UIImage(systemName: "checkmark.seal.fill")
                tickimage.tintColor = .white
            }
        case .pending:
            approvedpending.text = "Pending"
            approvedpending.textColor = .label
            tickimage.image = UIImage(systemName: "questionmark.circle.dashed")
            tickimage.tintColor = .white
        case .cancelled:
            approvedpending.text = "Cancelled"
            approvedpending.textColor = .label
            tickimage.image = UIImage(systemName: "xmark.circle.fill")
            tickimage.tintColor = .white
            // Hide payment and action buttons
            paymentButton.isHidden = true
            extendReturnButtonsStack?.isHidden = true
            returnStatusLabel?.isHidden = true
            extensionStatusLabel?.isHidden = true
        case .rejected:
            approvedpending.text = "Rejected"
            approvedpending.textColor = .label
            tickimage.image = UIImage(systemName: "xmark.circle.fill")
            tickimage.tintColor = .white
            // Hide payment and action buttons
            paymentButton.isHidden = true
            extendReturnButtonsStack?.isHidden = true
            returnStatusLabel?.isHidden = true
            extensionStatusLabel?.isHidden = true
        case .completed:
            approvedpending.text = "Completed"
            approvedpending.textColor = .label
            tickimage.image = UIImage(systemName: "checkmark.seal.fill")
            tickimage.tintColor = .white
            circ2?.backgroundColor = brandTeal
            // Hide payment and action buttons (rental is done)
            paymentButton.isHidden = true
            extendReturnButtonsStack?.isHidden = true
            returnStatusLabel?.isHidden = true
            extensionStatusLabel?.isHidden = true
        }

        tickimage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        tickimage.contentMode = .scaleAspectFit

        // Button title from status (only applies in myRentals mode where button is visible)
        if mode == .myRentals && status != .cancelled && status != .rejected {
            paymentButton.setTitle("Pay via UPI", for: .normal)
            paymentButton.setTitleColor(.white, for: .normal)
            paymentButton.backgroundColor = brandTeal
        }

        // Update paymentStatus label to show rental status text
        updatePaymentStatusLabel()
        refreshPaymentRowVisibility()

        // Update extend/return button titles based on current request status
        updateReturnButtonForRequestStatus()
        updateExtensionButtonState()

        // Update chat/direction/address state based on acceptance
        updateOwnerCardInteractivity()
    }

    private func applyRequestToUI() {
        guard let req = request else { return }

        // Map status string to RequestStatus using the canonical RentalStatus enum
        let rentalStatus = req.rentalStatus
        setStatus(rentalStatus.bookingApprovalStatus)

        // Defensive: Auto-derive mode based on current user if not explicitly set
        // This acts as a fallback to prevent edge cases
        Task { [weak self] in
            guard let self = self else { return }
            guard let currentUserId = await SupabaseManager.shared.currentUserId() else { return }
            
            await MainActor.run {
                // If current user is the owner, we're in history mode (owner viewing borrower's request)
                // Otherwise, we're in myRentals mode (borrower viewing their own request)
                let derivedMode: PresentationMode = (currentUserId == req.owner_id) ? .history : .myRentals
                
                // Only auto-set if mode is still at default (.myRentals) and we detect we should be in .history
                // This is a defensive measure; normally mode should be set by the caller
                if self.mode == .myRentals && derivedMode == .history {
                    debugLog("[BookingApproval] Auto-derived mode: .history (currentUser is owner)")
                    self.mode = .history
                }
            }
        }

        // Dates
        if let booking = BookingPresentationFormatter.presentation(from: req, pricePerDay: req.items?.price_per_day ?? 0) {
            self.startDate = booking.pickupDateTime
            self.pickupTime = booking.pickupDateTime
            self.returnTime = booking.returnDateTime
        } else {
            let sDate = sqlDateFormatter.date(from: req.start_date)
            let eDate = sqlDateFormatter.date(from: req.end_date)
            let pTime = (req.pickup_time != nil && !(req.pickup_time ?? "").isEmpty) ? sqlTimeParser.date(from: req.pickup_time!) : nil
            self.startDate = sDate
            self.returnTime = eDate
            self.pickupTime = pTime
        }
        updateDatesUI()

        // Title/image — lightweight, fine to do synchronously
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

        // Show code digits if pickup_code exists, else zeros
        if let code = req.pickup_code, !code.isEmpty {
            setCodeDigits(from: code)
        } else {
            setCodeDigits(from: "000000")
        }

        // Network-dependent data (owner info, address, amounts) is loaded
        // in viewDidAppear so it doesn't block/slow the push animation.
        // We only set the loading state once, preventing background refreshes from overriding the fetched name.
        if ownNameLabel?.text == nil || ownNameLabel?.text?.isEmpty == true || ownNameLabel?.text == "Loading lender..." || ownNameLabel?.text == "Loading borrower..." {
            let participantFallback = fallbackParticipantName
            ownNameLabel?.text = mode == .history ? "Loading borrower..." : "Loading lender..."
            renderOwnerInitials(fullName: participantFallback)
        }
    }

    private func selectClause() -> String {
        if RequestSchemaSupport.supportsPickupCode {
            return """
            id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,pickup_code,
            items(id,title,images,price_per_day,category)
            """
        }

        return """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,
        items(id,title,images,price_per_day,category)
        """
    }

    private func mapRefreshedRow(_ fresh: RequestWithItem) {
        self.request = fresh
        
        // Recompute the presentation to handle extended dates and time
        if let booking = BookingPresentationFormatter.presentation(from: fresh, pricePerDay: fresh.items?.price_per_day ?? 0) {
            self.startDate = booking.pickupDateTime
            self.pickupTime = booking.pickupDateTime
            self.returnTime = booking.returnDateTime
        } else {
            let sqlDateFormatter = BookingPresentationFormatter.sqlDateFormatter
            self.startDate = sqlDateFormatter.date(from: fresh.start_date)
            self.returnTime = sqlDateFormatter.date(from: fresh.end_date)
            self.pickupTime = BookingPresentationFormatter.parseTime(fresh.pickup_time)
        }
        
        self.updateDatesUI()
        
        // Also fire off a UI update for the new amounts (so the price breakdown updates)
        Task { [weak self] in
            guard let self else { return }
            let amounts = await self.computeAmounts(for: fresh)
            await MainActor.run {
                self.updateAmountLabels(rental: amounts.rentalFee, deposit: 0, total: amounts.rentalFee)
            }
        }
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
            if RequestSchemaSupport.isMissingPickupCodeError(error), RequestSchemaSupport.supportsPickupCode {
                RequestSchemaSupport.markPickupCodeUnavailable()
                await refreshRequestFromDBIfPossible()
            }
            // ignore
        }
    }

    private func refreshRentalPaymentState() async {
        guard let requestId = request?.id else { return }
        do {
            let state = try await RentalPaymentStateService.shared.fetch(requestId: requestId)
            await MainActor.run {
                self.rentalPaymentState = state
                self.updateStatusUI()
            }
        } catch {
            debugLog("[BookingApproval] Failed to refresh payment state: \(error.localizedDescription)")
        }
    }

    // MARK: - Owner card interactivity (chat, direction, address)

    /// Enables or disables the chat and direction buttons, and controls the address label
    /// based on whether the rental request has been accepted by the lender.
    private func updateOwnerCardInteractivity() {
        // Owner (history mode) always has full access to borrower info
        guard mode == .myRentals else {
            chatButton?.isEnabled = true
            chatButton?.alpha = 1.0
            getdirectionbutton?.isEnabled = true
            getdirectionbutton?.alpha = 1.0
            copybutton?.isEnabled = true
            copybutton?.alpha = 1.0
            return
        }

        let isAcceptedOrBeyond = (status == .approved || status == .completed)

        if isAcceptedOrBeyond {
            // Enable chat and direction buttons
            chatButton?.isEnabled = true
            chatButton?.alpha = 1.0
            getdirectionbutton?.isEnabled = true
            getdirectionbutton?.alpha = 1.0
            copybutton?.isEnabled = true
            copybutton?.alpha = 1.0

            // Reset address label color in case it was the placeholder
            addressLabel?.textColor = .label

            // If address is still showing placeholder, trigger fetch now
            let currentAddr = addressLabel?.text ?? ""
            if currentAddr.isEmpty || currentAddr.contains("will be enabled") || currentAddr == "Address unavailable" {
                Task { [weak self] in
                    guard let self, let req = self.request else { return }
                    await self.fetchAndDisplayAddress(for: req.owner_id)
                }
            }
        } else {
            // Disable chat and direction buttons
            chatButton?.isEnabled = false
            chatButton?.alpha = 0.4
            getdirectionbutton?.isEnabled = false
            getdirectionbutton?.alpha = 0.4
            copybutton?.isEnabled = false
            copybutton?.alpha = 0.4

            // Show informational placeholder instead of "Address unavailable"
            addressLabel?.text = "Address and chat will be enabled when owner accepts rental request"
            addressLabel?.textColor = .secondaryLabel
            addressLabel?.font = .systemFont(ofSize: 14)
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

    // MARK: - Payments removed (DB-driven)

    // MARK: - Compute amounts (rental fee only)

    private func computeAmounts(for req: RequestWithItem) async -> (rentalFee: Double, deposit: Double) {
        let rentalFee = BookingPresentationFormatter.presentation(
            from: req,
            pricePerDay: req.items?.price_per_day ?? 0
        )?.rentalFee ?? 0

        // Deposit always zero as per new logic
        let depositAmount: Double = 0

        return (rentalFee, depositAmount)
    }
    
    // New helper for UPI amount compute (only rental fee)
    private func computeAmountsForUPI(for req: RequestWithItem) async -> Double {
        BookingPresentationFormatter.presentation(
            from: req,
            pricePerDay: req.items?.price_per_day ?? 0
        )?.rentalFee ?? 0
    }

    private func durationDays(for req: RequestWithItem) -> Int {
        BookingPresentationFormatter.presentation(
            from: req,
            pricePerDay: req.items?.price_per_day ?? 0
        )?.quantityUnits ?? 1
    }

    private func currentUserDisplayName() async -> String {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return "Borrower" }

        struct Profile: Decodable {
            let full_name: String?
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("user_profiles")
                .select("full_name")
                .eq("id", value: userId)
                .single()
                .execute()

            let profile = try JSONDecoder().decode(Profile.self, from: response.data)
            let name = profile.full_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Borrower" : name
        } catch {
            return "Borrower"
        }
    }

    private func updateAmountLabels(rental: Double, deposit: Double, total: Double) {
        let rentalText = currencyFormatter.string(from: NSNumber(value: rental)) ?? String(format: "%.2f", rental)
        let totalText = currencyFormatter.string(from: NSNumber(value: total)) ?? String(format: "%.2f", total)

        fee?.text = rentalText
        seclabel?.isHidden = false
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
                .from("user_profiles")
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
                self?.renderOwner(fullName: self?.fallbackParticipantName, avatarURLString: nil)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: self?.fallbackParticipantName, avatarURLString: nil)
            }
        }
    }

    private func renderOwner(fullName: String?, avatarURLString: String?) {
        let name = formattedDisplayName(fullName, fallback: fallbackParticipantName)
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

    private var fallbackParticipantName: String {
        mode == .history ? "Borrower" : "Lender"
    }

    private func formattedDisplayName(_ rawValue: String?, fallback: String) -> String {
        let cleaned = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                let lowercased = token.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ") ?? ""

        return cleaned.isEmpty ? fallback : cleaned
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

    private func setupLoadingOverlay() {
        guard loadingOverlay == nil else { return }

        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        overlay.isHidden = true

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = brandTeal

        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.font = .systemFont(ofSize: 15, weight: .medium)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.text = "Loading booking details..."

        overlay.addSubview(loadingIndicator)
        overlay.addSubview(loadingLabel)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -12),

            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24)
        ])

        loadingOverlay = overlay
    }

    private func setLoading(_ loading: Bool, message: String = "Loading booking details...") {
        loadingLabel.text = message
        loadingOverlay?.isHidden = !loading
        if loading {
            loadingIndicator.startAnimating()
            if let overlay = loadingOverlay {
                view.bringSubviewToFront(overlay)
            }
        } else {
            loadingIndicator.stopAnimating()
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

    // MARK: - Payment status label helper (repurposed for rental status display)

    private func updatePaymentStatusLabel() {
        if shouldShowPaymentCTA {
            paymentStatus?.text = nil
            paymentStatus?.isHidden = true
            return
        }

        let rawStatus = request?.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if rawStatus == "accepted" {
            if rentalPaymentState.lenderConfirmedReceived {
                paymentStatus?.text = "Payment received. Your pickup code is ready."
                paymentStatus?.textColor = brandTeal
            } else if rentalPaymentState.borrowerMarkedPaid {
                paymentStatus?.text = "Payment marked as sent. Waiting for lender confirmation."
                paymentStatus?.textColor = statusWarningColor
            } else {
                paymentStatus?.text = "Pay the lender directly via UPI to continue."
                paymentStatus?.textColor = statusWarningColor
            }
            paymentStatus?.isHidden = false
            return
        }

        switch self.status {
        case .approved:
            paymentStatus?.text = "Pickup Verified"
            paymentStatus?.textColor = brandTeal
            paymentStatus?.isHidden = false
        case .pending:
            paymentStatus?.text = "Awaiting Confirmation"
            paymentStatus?.textColor = statusWarningColor
            paymentStatus?.isHidden = false
        case .cancelled:
            paymentStatus?.text = "Rental Cancelled"
            paymentStatus?.textColor = .systemRed
            paymentStatus?.isHidden = false
        case .rejected:
            paymentStatus?.text = "Request Declined"
            paymentStatus?.textColor = .systemRed
            paymentStatus?.isHidden = false
        case .completed:
            paymentStatus?.text = "Rental Completed"
            paymentStatus?.textColor = .label
            paymentStatus?.isHidden = false
        }
    }
    
    // MARK: - Toast notification helper
    
    private func showToast(message: String, fromBottom: Bool = true) {
        // Create a label for the toast
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        toastLabel.text = message
        toastLabel.numberOfLines = 0
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        // Size the label
        let maxSize = CGSize(width: view.bounds.width - 80, height: 100)
        let expectedSize = toastLabel.sizeThatFits(maxSize)
        let width = min(expectedSize.width + 40, view.bounds.width - 40)
        let height = expectedSize.height + 20
        
        toastLabel.frame = CGRect(
            x: (view.bounds.width - width) / 2,
            y: fromBottom ? view.bounds.height - 100 : view.safeAreaInsets.top + 20,
            width: width,
            height: height
        )
        
        view.addSubview(toastLabel)
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            toastLabel.alpha = 1
        }) { _ in
            // Animate out after delay
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - UPI Payment helpers
    
    private func openUPILink(payee: String?, payeeName: String, amount: Double) {
        guard let upi = payee, !upi.isEmpty else {
            let a = UIAlertController(title: "UPI ID missing", message: "The lender hasn't added a UPI ID yet. Open chat and ask them to share one before you pay.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Open Chat", style: .default) { [weak self] _ in
                self?.openChatSafely()
            })
            a.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(a, animated: true)
            return
        }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        let tn = "Rentiwise Rental"
        let query = "upi://pay?pa=\(upi)&pn=\(payeeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&am=\(amountString)&cu=INR&tn=\(tn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: query), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let a = UIAlertController(
                title: "Complete Payment Manually",
                message: "No supported UPI app was found on this device. You can still copy the lender's payment details and complete the transfer manually.",
                preferredStyle: .actionSheet
            )
            a.addAction(UIAlertAction(title: "Copy UPI ID", style: .default) { [weak self] _ in
                UIPasteboard.general.string = upi
                self?.showToast(message: "UPI ID copied", fromBottom: false)
            })
            a.addAction(UIAlertAction(title: "Copy Amount", style: .default) { [weak self] _ in
                UIPasteboard.general.string = amountString
                self?.showToast(message: "Amount copied", fromBottom: false)
            })
            a.addAction(UIAlertAction(title: "Open Chat", style: .default) { [weak self] _ in
                self?.openChatSafely()
            })
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = a.popoverPresentationController {
                popover.sourceView = paymentButton
                popover.sourceRect = paymentButton?.bounds ?? view.bounds
            }
            present(a, animated: true)
        }
    }
}
