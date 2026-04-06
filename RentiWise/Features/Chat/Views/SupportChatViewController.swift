// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata
//
//  SupportChatViewController.swift
//  RentiWise
//
//  Support chat view controller with Supabase ticket system
//

import UIKit
import Supabase

final class SupportChatViewController: UIViewController {
    
    private let chatService: SupportChatServicing = SupportChatService()
    
    // MARK: - Properties
    
    private var currentTicket: SupportTicket?
    private var messages: [SupportMessage] = []
    private var currentUserId: String?
    
    private let quickActionTopics = ["Refund", "Booking Issue", "Damage Report", "Account Help", "Other"]
    
    // MARK: - UI Elements
    
    // Removed headerView and headerLabel

    private let ticketStatusCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0).cgColor
        view.isHidden = true
        return view
    }()
    
    private let ticketStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Support Contact"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        return label
    }()
    
    private let ticketIdLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Use in-app support or email support@rentiwise.com"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        tv.dataSource = self
        tv.delegate = self
        tv.register(SupportMessageCell.self, forCellReuseIdentifier: SupportMessageCell.reuseIdentifier)
        return tv
    }()
    
    private let quickActionsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        sv.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        return sv
    }()
    
    private let quickActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        return stack
    }()
    
    private let inputContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white  // White box like iOS Messages
        return view
    }()
    
    private let inputTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Describe your issue..."
        tf.font = .systemFont(ofSize: 16)
        tf.borderStyle = .none
        tf.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        tf.layer.cornerRadius = 20
        tf.layer.shadowColor = UIColor.black.cgColor
        tf.layer.shadowOpacity = 0.05
        tf.layer.shadowRadius = 2
        tf.layer.shadowOffset = CGSize(width: 0, height: 1)
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.rightViewMode = .always
        return tf
    }()
    
    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        btn.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        btn.contentVerticalAlignment = .fill
        btn.contentHorizontalAlignment = .fill
        btn.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        return btn
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private var inputContainerBottomConstraint: NSLayoutConstraint!
    private var inputContainerHeightConstraint: NSLayoutConstraint!
    private var ticketStatusHeightConstraint: NSLayoutConstraint!
    
    // Two alternate top constraints for the table
    private var tableTopToSafeArea: NSLayoutConstraint!
    private var tableTopToCard: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Support"
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        
        setupUI()
        setupQuickActions()
        setupKeyboardObservers()
        loadInitialState()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Removed headerView/headerLabel
        view.addSubview(ticketStatusCard)
        ticketStatusCard.addSubview(ticketStatusLabel)
        ticketStatusCard.addSubview(ticketIdLabel)
        view.addSubview(tableView)
        view.addSubview(quickActionsScrollView)
        quickActionsScrollView.addSubview(quickActionsStack)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)
        view.addSubview(loadingIndicator)
        
        // Input container extends below safe area like iOS Messages
        inputContainerBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        // Dynamic height: 70pt + safe area bottom inset (more space at bottom)
        let safeBottom = view.safeAreaInsets.bottom
        let totalHeight = 70 + safeBottom
        inputContainerHeightConstraint = inputContainerView.heightAnchor.constraint(equalToConstant: totalHeight)
        
        ticketStatusHeightConstraint = ticketStatusCard.heightAnchor.constraint(equalToConstant: 72)
        
        // Build constraints
        // When no card is visible, pin table to the very top of the view (not the safe area)
        tableTopToSafeArea = tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        // When card is visible, pin the table under the card
        tableTopToCard = tableView.topAnchor.constraint(equalTo: ticketStatusCard.bottomAnchor, constant: 0) // spacing can be adjusted when card is visible
        
        NSLayoutConstraint.activate([
            // Ticket status card (pinned to safe area top)
            ticketStatusCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            ticketStatusCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ticketStatusCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ticketStatusHeightConstraint,
            
            ticketStatusLabel.leadingAnchor.constraint(equalTo: ticketStatusCard.leadingAnchor, constant: 16),
            ticketStatusLabel.topAnchor.constraint(equalTo: ticketStatusCard.topAnchor, constant: 8),
            
            ticketIdLabel.leadingAnchor.constraint(equalTo: ticketStatusCard.leadingAnchor, constant: 16),
            ticketIdLabel.bottomAnchor.constraint(equalTo: ticketStatusCard.bottomAnchor, constant: -8),
            
            // Table view (top constraint toggled below)
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: quickActionsScrollView.topAnchor),
            
            // Quick actions
            quickActionsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quickActionsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            quickActionsScrollView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),
            quickActionsScrollView.heightAnchor.constraint(equalToConstant: 50),
            
            quickActionsStack.leadingAnchor.constraint(equalTo: quickActionsScrollView.leadingAnchor, constant: 16),
            quickActionsStack.trailingAnchor.constraint(equalTo: quickActionsScrollView.trailingAnchor, constant: -16),
            quickActionsStack.centerYAnchor.constraint(equalTo: quickActionsScrollView.centerYAnchor),
            quickActionsStack.heightAnchor.constraint(equalToConstant: 36),
            
            // Input container - extends below safe area with white background
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerBottomConstraint,
            inputContainerHeightConstraint,
            
            // Input field - pinned to top with safe area padding at bottom
            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 10),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),
            
            sendButton.leadingAnchor.constraint(equalTo: inputTextField.trailingAnchor, constant: 12),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        ticketStatusCard.isHidden = false
        ticketStatusHeightConstraint.isActive = true
        
        tableTopToSafeArea.isActive = false
        tableTopToCard.isActive = true
        
        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }
    
    private func setupQuickActions() {
        for topic in quickActionTopics {
            let button = UIButton(type: .system)
            button.setTitle(topic, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.setTitleColor(UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0), for: .normal)
            button.backgroundColor = .white
            button.layer.cornerRadius = 18
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.05
            button.layer.shadowRadius = 2
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.addTarget(self, action: #selector(quickActionTapped(_:)), for: .touchUpInside)
            quickActionsStack.addArrangedSubview(button)
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update height dynamically to account for safe area
        let safeBottom = view.safeAreaInsets.bottom
        inputContainerHeightConstraint.constant = 70 + safeBottom
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        // Move entire input container up by keyboard height
        inputContainerBottomConstraint.constant = -frame.height
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        // Return to bottom of screen
        inputContainerBottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Data Loading
    
    private func loadInitialState() {
        Task {
            currentUserId = await SupabaseManager.shared.currentUserId()
            // Try to load existing open ticket and its history
            await loadExistingTicketAndMessages()
            await MainActor.run {
                self.updateStatusCard()
            }
        }
    }

    /// Loads the most recent open support ticket for the current user.
    /// If found, fetches all messages for that ticket so history is preserved.
    private func loadExistingTicketAndMessages() async {
        guard let userId = currentUserId else {
            await addWelcomeMessage()
            return
        }

        do {
            // Fetch the newest open (or in_progress) ticket for this user
            struct TicketRow: Decodable {
                let id: String
                let user_id: String
                let subject: String
                let status: String
                let priority: String
                let created_at: String
                let updated_at: String?
                let resolved_at: String?
            }

            let ticketRows: [TicketRow] = try await SupabaseManager.shared.client
                .from("support_tickets")
                .select()
                .eq("user_id", value: userId)
                .in("status", values: ["open", "in_progress"])
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let latestTicket = ticketRows.first {
                // Convert to SupportTicket model
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let ticketData = try JSONSerialization.data(withJSONObject: [
                    "id": latestTicket.id,
                    "user_id": latestTicket.user_id,
                    "subject": latestTicket.subject,
                    "status": latestTicket.status,
                    "priority": latestTicket.priority,
                    "created_at": latestTicket.created_at,
                    "updated_at": latestTicket.updated_at as Any,
                    "resolved_at": latestTicket.resolved_at as Any
                ].compactMapValues { $0 })
                let ticket = try decoder.decode(SupportTicket.self, from: ticketData)

                // Fetch all messages for this ticket
                struct MessageRow: Decodable {
                    let id: String
                    let ticket_id: String
                    let sender_id: String
                    let text: String
                    let is_from_support: Bool
                    let created_at: String
                }
                let messageRows: [MessageRow] = try await SupabaseManager.shared.client
                    .from("support_messages")
                    .select()
                    .eq("ticket_id", value: ticket.id)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let isoFallback = ISO8601DateFormatter()

                let loadedMessages: [SupportMessage] = messageRows.map { row in
                    let date = iso.date(from: row.created_at) ?? isoFallback.date(from: row.created_at) ?? Date()
                    return SupportMessage(
                        id: row.id,
                        ticket_id: row.ticket_id,
                        sender_id: row.sender_id,
                        text: row.text,
                        is_from_support: row.is_from_support,
                        created_at: date
                    )
                }

                await MainActor.run {
                    self.currentTicket = ticket
                    if loadedMessages.isEmpty {
                        self.addWelcomeMessageSync()
                    } else {
                        self.messages = loadedMessages
                    }
                    self.tableView.reloadData()
                    self.scrollToBottom()
                }
                return
            }
        } catch {
            debugLog("[SupportChat] Failed to load existing ticket: \(error.localizedDescription)")
        }

        // No existing ticket found — show welcome
        await addWelcomeMessage()
    }

    private func updateStatusCard() {
        if let ticket = currentTicket {
            ticketStatusLabel.text = "Ticket #\(ticket.id.prefix(8))"
            let statusText: String
            switch ticket.status {
            case .open: statusText = "Open"
            case .inProgress: statusText = "In Progress"
            case .resolved: statusText = "Resolved"
            case .closed: statusText = "Closed"
            }
            ticketIdLabel.text = "\(statusText) • Reply here or email support@rentiwise.com"
        } else {
            ticketStatusLabel.text = "Support Contact"
            ticketIdLabel.text = "Use in-app support or email support@rentiwise.com"
        }
    }
    
    private func addWelcomeMessage() async {
        await MainActor.run {
            addWelcomeMessageSync()
            tableView.reloadData()
        }
    }

    private func addWelcomeMessageSync() {
        let welcomeMessage = SupportMessage(
            id: "welcome",
            ticket_id: "",
            sender_id: "system",
            text: "Hello! I'm the Rentiwise Assistant. Choose a topic below or type your question.",
            is_from_support: true,
            created_at: Date()
        )
        messages = [welcomeMessage]
    }
    
    // MARK: - Actions
    
    @objc private func quickActionTapped(_ sender: UIButton) {
        guard let topic = sender.title(for: .normal) else { return }
        sendQuery(topic)
    }
    
    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        sendQuery(text)
    }
    
    private func sendQuery(_ text: String) {
        inputTextField.text = ""
        
        // Add user message locally first
        let userMessage = SupportMessage(
            id: UUID().uuidString,
            ticket_id: currentTicket?.id ?? "",
            sender_id: currentUserId ?? "",
            text: text,
            is_from_support: false,
            created_at: Date()
        )
        messages.append(userMessage)
        tableView.reloadData()
        scrollToBottom()
        
        Task {
            loadingIndicator.startAnimating()
            
            do {
                let subjectText = text
                let messageText = text
                
                // Create ticket if not exists
                if currentTicket == nil {
                    let ticket = try await chatService.createSupportTicket(subject: subjectText, message: messageText)
                    await MainActor.run {
                        currentTicket = ticket
                        updateStatusCard()
                        
                        UIView.animate(withDuration: 0.25) {
                            self.view.layoutIfNeeded()
                        }
                    }
                } else {
                    // Send message to existing ticket
                    _ = try await chatService.sendSupportMessage(ticketId: currentTicket!.id, text: text)
                }
                
                // Simulate bot response (in production, this would come from server)
                await MainActor.run {
                    loadingIndicator.stopAnimating()
                    addBotResponse(for: text)
                }
                
            } catch {
                await MainActor.run {
                    loadingIndicator.stopAnimating()
                    addBotResponse(for: text) // Still show response even if save failed
                }
            }
        }
    }
    
    private func addBotResponse(for query: String) {
        let response = generateBotResponse(for: query)
        let botMessage = SupportMessage(
            id: UUID().uuidString,
            ticket_id: currentTicket?.id ?? "",
            sender_id: "support",
            text: response,
            is_from_support: true,
            created_at: Date()
        )
        messages.append(botMessage)
        tableView.reloadData()
        scrollToBottom()

        // Persist the bot auto-response to DB so it appears in chat history
        if let ticketId = currentTicket?.id {
            Task {
                try? await chatService.sendSupportMessage(ticketId: ticketId, text: response)
            }
        }
    }
    
    private func generateBotResponse(for query: String) -> String {
        let lowercased = query.lowercased()
        
        if lowercased.contains("refund") || lowercased.contains("money back") {
            return "🔄 Refund Help\n\nRentiwise does not hold payments or issue refunds directly. Payments are arranged between the lender and borrower.\n\nIf you've already paid the lender, please:\n• Check the booking chat for the payment agreement\n• Request the refund directly from the lender\n• Share your booking ID with support if there is a dispute\n\nWe can review account activity and help document the issue, but we do not reverse or settle payments in-app."
        } else if lowercased.contains("booking") || lowercased.contains("reservation") {
            return "📅 Booking Assistance\n\nI can help you with:\n• Modifying booking dates\n• Checking item availability\n• Understanding pricing\n• Cancellation policies\n\nPlease tell me your booking ID or describe the specific issue you're facing."
        } else if lowercased.contains("damage") || lowercased.contains("broken") {
            return "⚠️ Damage Report\n\nThank you for reporting this. To process your claim:\n\n1. Take clear photos of the damage\n2. Provide your booking ID\n3. Describe when/how it happened\n\nOur team will review within 24 hours and contact you. For items damaged during rental, insurance may cover the cost."
        } else if lowercased.contains("account") || lowercased.contains("profile") || lowercased.contains("password") {
            return "👤 Account Support\n\nI can help you with:\n• Password reset\n• Profile updates\n• Email/phone verification\n• Account security\n\nWhat specific account issue are you experiencing? I'll guide you through the solution."
        } else if lowercased.contains("payment") || lowercased.contains("card") || lowercased.contains("charge") || lowercased.contains("upi") {
            return "💳 Payment Help\n\nRentiwise does not process card payments or store payment details.\n\nFor rentals:\n• Pay the lender directly via UPI after the request is accepted\n• Confirm the amount and UPI ID inside the booking screen\n• Use the booking chat if you need to confirm receipt or resolve an issue\n\nIf a UPI ID is missing or something looks suspicious, send your booking ID and we will help review it."
        } else if lowercased.contains("cancel") {
            return "❌ Cancellation Help\n\nYou can cancel a request or rental from the booking screen.\n\nIf you've already paid the lender directly:\n• Coordinate any refund with the lender in chat\n• Keep screenshots of the agreement and payment confirmation\n• Contact support with your booking ID if the cancellation becomes a dispute\n\nRentiwise can help review account activity, but payment settlement still happens directly between users."
        } else if lowercased.contains("hi") || lowercased.contains("hello") || lowercased.contains("hey") {
            return "👋 Hello! Welcome to Rentiwise Support.\n\nHow can I help you today? Common topics:\n\n📦 Bookings & Rentals\n💰 Payments & Refunds\n⚙️ Account Issues\n📞 Report a Problem\n\nFeel free to ask anything or choose a topic above!"
        } else {
            return "✨ Thank you for contacting Rentiwise Support!\n\nA support representative will review your inquiry and respond within 2-4 hours. For faster assistance, please provide:\n\n• Your booking ID (if applicable)\n• Detailed description of the issue\n• Any relevant screenshots\n\nYou can also check our FAQ in the app settings while you wait."
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDataSource

extension SupportChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SupportMessageCell.reuseIdentifier, for: indexPath) as! SupportMessageCell
        let message = messages[indexPath.row]
        cell.configure(with: message)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SupportChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - SupportMessageCell

final class SupportMessageCell: UITableViewCell {
    
    static let reuseIdentifier = "SupportMessageCell"
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(timestampLabel)
        
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            
            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with message: SupportMessage) {
        messageLabel.text = message.text
        timestampLabel.text = message.formattedTime
        
        bubbleLeadingConstraint.isActive = false
        bubbleTrailingConstraint.isActive = false
        
        if message.is_from_support {
            bubbleLeadingConstraint.isActive = true
            bubbleView.backgroundColor = .white
            messageLabel.textColor = .label
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
        } else {
            bubbleTrailingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
            messageLabel.textColor = .white
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
        }
    }
}
