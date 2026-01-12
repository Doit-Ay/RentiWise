//
//  BookingApprovalViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit

class BookingApprovalViewController: UIViewController {

    enum RequestStatus {
        case approved
        case pending
    }

    static let requestApprovedNotification = Notification.Name("BookingApprovalRequestApprovedNotification")

    // Current request status; set this from outside as needed
    var status: RequestStatus = .pending {
        didSet {
            print("[BookingApproval] Status changed to: \(status)")
            updateStatusUI()
        }
    }

    // Booking dates passed from RequestViewController
    private var startDate: Date?
    private var pickupTime: Date?
    private var returnTime: Date?

    // Tracks if a payment has been completed
    private var hasCompletedPayment: Bool = false

    // Observer token to manage notification observer lifecycle
    private var approvalObserver: NSObjectProtocol?
    private var requestsRefreshObserver: NSObjectProtocol?

    // Connect this to the Proceed to Payment button in Interface Builder
    
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
    
    private func updateDatesUI() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

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
    
    // Generates and assigns a unique 6-digit numeric code to the code labels
    func generateNewCode() {
        let digits = (0..<6).map { _ in String(Int.random(in: 0...9)) }
        let labels: [UILabel?] = [code1Label, code2Label, code3Label, code4Label, code5Label, code6Label]
        for (i, lbl) in labels.enumerated() {
            lbl?.text = digits[i]
        }
    }

    private func updateStatusUI() {
        // Update status visuals
        switch status {
        case .approved:
            approvedpending.text = "Approved"
            tickimage.image = UIImage(systemName: "checkmark.circle")
            tickimage.tintColor = .systemGreen
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

        // Show/hide View Code container depending on payment status and adjust layout
        let shouldShowCode = hasCompletedPayment
        viewCodeUIView.isHidden = !shouldShowCode
        if shouldShowCode {
            viewCodeHeight?.constant = collapsedViewCodeHeight
            statusToViewCodeTop?.constant = 0
        } else {
            viewCodeHeight?.constant = 0
            statusToViewCodeTop?.constant = 0
        }
    }

    // Height constraint for the new "View Code" container
    @IBOutlet weak var viewCodeHeight: NSLayoutConstraint!

    // Collapse/expand helpers
    private var codeStackCollapseConstraint: NSLayoutConstraint?

    // Heights
    private let collapsedViewCodeHeight: CGFloat = 56
    private let expandedViewCodeHeight: CGFloat = 140

    override func viewDidLoad() {
        super.viewDidLoad()

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

        // Style payment button with black border
        paymentButton.layer.borderColor = UIColor.black.cgColor
        paymentButton.layer.borderWidth = 1
        paymentButton.layer.cornerRadius = 8
        paymentButton.layer.masksToBounds = true

        // Style get direction and copy buttons with black border
        getdirectionbutton.layer.borderColor = UIColor.black.cgColor
        getdirectionbutton.layer.borderWidth = 1
        getdirectionbutton.layer.cornerRadius = 8
        getdirectionbutton.layer.masksToBounds = true

        copybutton.layer.borderColor = UIColor.black.cgColor
        copybutton.layer.borderWidth = 1
        copybutton.layer.cornerRadius = 8
        copybutton.layer.masksToBounds = true

        // Start in Pending state and disable payment until accepted
        status = .pending
        paymentButton.isEnabled = false
        paymentButton.alpha = 0.5

        // Initialize status UI based on current status
        updateStatusUI()

        // Generate a fresh 6-digit code for the current product selection
        generateNewCode()
        
        // Apply glass effect to key cards
        

        // Reflect any pre-configured dates
        updateDatesUI()

        // TEMP: Populate with sample values so the screen always shows data
        if startDate == nil && pickupTime == nil && returnTime == nil {
            let now = Date()
            let pickup = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: now)
            let returnDate = Calendar.current.date(byAdding: .day, value: 2, to: now)
            configureDates(startDate: now, pickupTime: pickup, returnTime: returnDate)
        }
        
        // Removed old observer registration here (moved to viewWillAppear)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure Booking Period reflects latest configured dates
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
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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

    // Configure booking dates/times from RequestViewController
    func configureDates(startDate: Date?, pickupTime: Date?, returnTime: Date?) {
        self.startDate = startDate
        self.pickupTime = pickupTime
        self.returnTime = returnTime
        updateDatesUI()
    }

    @objc private func handleExternalApproval() {
        DispatchQueue.main.async {
            print("[BookingApproval] External approval received -> setting status Approved")
            self.setStatus(.approved)
        }
    }

    // Call this when a new product is selected from My Rentals to refresh the pickup code
    func didSelectNewProductFromMyRentals() {
        hasCompletedPayment = false
        viewCodeUIView.isHidden = true
        statusToViewCodeTop?.constant = 16
        paymentButton.setTitle("Proceed to Payment", for: .normal)
        generateNewCode()
        updateStatusUI()
    }

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        // Mark as approved; UI updates automatically via didSet
        setStatus(.approved)
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        // Keep pending if denied (adjust if you want a separate denied state)
        setStatus(.pending)
    }

    @IBAction func ViewHideCodeButton(_ sender: UIButton) {
        let isCurrentlyShowingCode = (sender.title(for: .normal) ?? "") == "Hide Code"
        let shouldShowCode = !isCurrentlyShowingCode

        sender.setTitle(shouldShowCode ? "Hide Code" : "View Code", for: .normal)

        if shouldShowCode {
            // Expand the View Code container and reveal the stack
            codeStackCollapseConstraint?.isActive = false
            codestack.isHidden = false
            viewCodeHeight?.constant = expandedViewCodeHeight
            viewCodeHeight?.isActive = true
        } else {
            // Collapse to button-only and hide the stack
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
        let actionSheet = UIAlertController(title: "Choose Payment Method", message: nil, preferredStyle: .actionSheet)

        let handlePaymentSelection: (String) -> Void = { method in
            // TODO: Integrate real payment flow for \(method)
            self.hasCompletedPayment = true
            // Reveal code view after successful payment
            self.viewCodeUIView.isHidden = false
            self.statusToViewCodeTop?.constant = 0
            // Update payment button title
            sender.setTitle("Payment Successful", for: .normal)
            // Refresh status UI to update icon tinting if needed
            self.updateStatusUI()
        }

        let applePay = UIAlertAction(title: "Apple Pay", style: .default) { _ in
            handlePaymentSelection("Apple Pay")
        }
        let cardPay = UIAlertAction(title: "Credit/Debit Card", style: .default) { _ in
            handlePaymentSelection("Card")
        }
        let cash = UIAlertAction(title: "Cash on Delivery", style: .default) { _ in
            handlePaymentSelection("Cash on Delivery")
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        actionSheet.addAction(applePay)
        actionSheet.addAction(cardPay)
        actionSheet.addAction(cash)
        actionSheet.addAction(cancel)

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
}

// MARK: - Glass effect fallback
extension UIView {
    @objc func applyGlassEffectSimple() {
        // If you already have a real implementation elsewhere, remove this fallback.
        self.backgroundColor = self.backgroundColor?.withAlphaComponent(0.5) ?? UIColor.systemBackground.withAlphaComponent(0.3)
        self.layer.cornerRadius = self.layer.cornerRadius == 0 ? 16 : self.layer.cornerRadius
        self.layer.masksToBounds = true
    }
}

