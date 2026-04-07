//
//  chatViewController.swift
//  RentiWise
//
//  Created by admin99 on 19/01/26.
//

import UIKit
import Supabase

final class ChatThreadViewController: UIViewController {

    // Context passed by caller
    // Required: otherUserId (the other participant), itemId (the item for item-bound chat)
    var otherUserId: String?
    var itemId: String?

    // Backend models
    private var conversation: ChatConversation?
    private var messages: [ChatMessage] = [] {
        didSet { refreshEmptyState() }
    }

    // Current user id
    private var currentUserId: String?

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBottomConstraint: NSLayoutConstraint?

    private let emptyStateLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Start your conversation"
        l.textAlignment = .center
        l.textColor = .secondaryLabel
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.isHidden = true
        return l
    }()

    // Realtime channel
    private var realtimeChannel: RealtimeChannelV2?

    private var periodicRefreshTimer: Timer?
    private let safetyService = CommunitySafetyService.shared
    private var otherParticipantDisplayName: String?

    private var isConversationBlocked: Bool {
        safetyService.isBlocked(otherUserId)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Chat"

        // Add a Close button for modal presentation
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(didTapSafetyMenu)
        )

        setupTable()
        setupInputBar()
        observeKeyboard()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockListChanged),
            name: CommunitySafetyService.blockedUsersDidChangeNotification,
            object: nil
        )
        applySafetyState()

        Task { await bootstrapConversationAndLoad() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // When the view is visible, mark as read if possible.
        Task { [weak self] in
            guard let self, let id = self.conversation?.id else { return }
            try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: id)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let channel = realtimeChannel
        if let channel {
            Task { await channel.unsubscribe() }
        }
        periodicRefreshTimer?.invalidate()
        periodicRefreshTimer = nil
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(BubbleCell.self, forCellReuseIdentifier: BubbleCell.reuseID)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])

        // Empty state overlay
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    private func setupInputBar() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.backgroundColor = .systemBackground
        inputBar.layer.shadowOpacity = 0.06
        inputBar.layer.shadowRadius = 4
        inputBar.layer.shadowOffset = CGSize(width: 0, height: -2)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholder = "Type a message..."
        inputField.borderStyle = .roundedRect
        inputField.returnKeyType = .send
        inputField.delegate = self

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputBar.addSubview(inputField)
        inputBar.addSubview(sendButton)
        view.addSubview(inputBar)

        inputBottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottomConstraint!,
            inputBar.heightAnchor.constraint(equalToConstant: 56),

            inputField.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 12),
            inputField.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 40),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),

            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
    }

    private func updateInsetsForKeyboard(height: CGFloat) {
        // Add bottom inset so last message is never under the input bar/keyboard
        var inset = tableView.contentInset
        inset.bottom = height + 56 // keyboard + input bar height
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(kbWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func kbWillShow(_ note: Notification) {
        guard
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }

        let keyboardHeight = max(0, frame.height - view.safeAreaInsets.bottom)
        inputBottomConstraint?.constant = -keyboardHeight
        updateInsetsForKeyboard(height: keyboardHeight)

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom(animated: true)
    }

    @objc private func kbWillHide(_ note: Notification) {
        guard
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        inputBottomConstraint?.constant = 0
        updateInsetsForKeyboard(height: 0)
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Backend wiring

    private func bootstrapConversationAndLoad() async {
        // Resolve user
        let uid = await SupabaseManager.shared.currentUserId()
        await MainActor.run { self.currentUserId = uid }

        // Validate parameters early and loudly
        guard let me = uid else {
            await MainActor.run { self.presentError("Please sign in to chat.") }
            return
        }

        let other = otherUserId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = itemId?.trimmingCharacters(in: .whitespacesAndNewlines)

        debugLog("[Chat] Starting conversation bootstrap")

        // Basic validation: must have other != me; item required for item-bound chat in this app
        if let other, !other.isEmpty, other == me {
            await MainActor.run { self.presentError("Cannot chat with yourself.") }
            return
        }
        guard let other, !other.isEmpty else {
            await MainActor.run { self.presentError("Missing other participant.") }
            return
        }
        guard let item, !item.isEmpty else {
            await MainActor.run { self.presentError("Missing item context for chat.") }
            return
        }
        if safetyService.isBlocked(other) {
            await MainActor.run {
                self.applySafetyState()
            }
            return
        }

        do {
            // Require itemId to ensure correct lender/borrower pairing
            let convo = try await ChatServiceV2.shared.getOrCreateConversation(withUserId: other, itemId: item)
            await MainActor.run {
                self.conversation = convo
                debugLog("[Chat] Conversation ready")
            }

            await loadOtherParticipantNameIfNeeded(userId: other)

            // Load messages
            let loaded = try await ChatServiceV2.shared.fetchMessages(conversationId: convo.id)
            await MainActor.run {
                debugLog("[Chat] Loaded \(loaded.count) messages")
                self.messages = loaded
                self.tableView.reloadData()
                self.scrollToBottom(animated: false)
            }

            // Mark as read
            try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: convo.id)

            // Subscribe for realtime updates
            await subscribeRealtime(conversationId: convo.id)
        } catch {
            await MainActor.run {
                self.presentError(error.localizedDescription)
            }
        }
    }

    @objc private func sendTapped() {
        Task {
            guard !isConversationBlocked else {
                await MainActor.run {
                    self.applySafetyState()
                }
                return
            }
            let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            guard let convoId = conversation?.id else {
                await MainActor.run { self.presentError("Chat is not ready yet.") }
                return
            }

            // Optimistic UX: clear input immediately
            await MainActor.run { self.inputField.text = nil }

            do {
                let sent = try await ChatServiceV2.shared.sendMessage(conversationId: convoId, text: text)
                await MainActor.run {
                    debugLog("[Chat] Message sent")
                    self.messages.append(sent)
                    self.tableView.reloadData()
                    self.scrollToBottom(animated: true)
                }
                // After sending, mark unread messages as read (keeps thread tidy)
                try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: convoId)
            } catch {
                await MainActor.run {
                    self.presentError(error.localizedDescription)
                }
            }
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let last = IndexPath(row: messages.count - 1, section: 0)
        if tableView.numberOfSections > 0 && tableView.numberOfRows(inSection: 0) > last.row {
            tableView.scrollToRow(at: last, at: .bottom, animated: animated)
        }
    }

    private func presentError(_ message: String) {
        let ac = UIAlertController(title: "Chat", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    private func refreshEmptyState() {
        if isConversationBlocked {
            emptyStateLabel.text = "You blocked this user. Unblock them in Privacy & Security to chat again."
            emptyStateLabel.isHidden = false
            return
        }

        emptyStateLabel.text = "Start your conversation"
        emptyStateLabel.isHidden = !messages.isEmpty
    }

    private func applySafetyState() {
        let blocked = isConversationBlocked
        tableView.isHidden = blocked
        inputBar.isHidden = blocked
        inputField.resignFirstResponder()
        if blocked {
            messages = []
            Task { await unsubscribeRealtime() }
            stopPeriodicRefresh()
        }
        refreshEmptyState()
    }

    @objc private func handleBlockListChanged() {
        applySafetyState()
        guard !isConversationBlocked, conversation != nil else { return }
        Task { await bootstrapConversationAndLoad() }
    }

    private func loadOtherParticipantNameIfNeeded(userId: String) async {
        guard otherParticipantDisplayName == nil else { return }
        struct UserProfileDTO: Decodable {
            let full_name: String?
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("user_profiles")
                .select("full_name")
                .eq("id", value: userId)
                .single()
                .execute()
            let dto = try JSONDecoder().decode(UserProfileDTO.self, from: response.data)
            await MainActor.run {
                self.otherParticipantDisplayName = dto.full_name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? dto.full_name : "User"
            }
        } catch {
            await MainActor.run {
                self.otherParticipantDisplayName = "User"
            }
        }
    }

    @objc private func didTapSafetyMenu(_ sender: UIBarButtonItem) {
        guard let otherUserId, !otherUserId.isEmpty else { return }

        let actionSheet = UIAlertController(title: "Safety Tools", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Report Conversation", style: .default) { [weak self] _ in
            self?.presentReportReasons(anchor: sender)
        })

        let isBlocked = safetyService.isBlocked(otherUserId)
        let blockTitle = isBlocked ? "Unblock User" : "Block User"
        actionSheet.addAction(UIAlertAction(title: blockTitle, style: .destructive) { [weak self] _ in
            guard let self else { return }
            if isBlocked {
                self.safetyService.unblock(userId: otherUserId)
                self.presentInfo("User Unblocked", message: "You can chat with them again.")
            } else {
                self.confirmBlockUser(userId: otherUserId)
            }
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(actionSheet, animated: true)
    }

    private func presentReportReasons(anchor: UIBarButtonItem) {
        let reasons = ["Harassment", "Scam or fraud", "Unsafe meetup", "Spam", "Other"]
        let actionSheet = UIAlertController(title: "Report Conversation", message: "Why are you reporting this chat?", preferredStyle: .actionSheet)
        for reason in reasons {
            actionSheet.addAction(UIAlertAction(title: reason, style: .default) { [weak self] _ in
                self?.presentReportDetails(reason: reason)
            })
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = anchor
        }
        present(actionSheet, animated: true)
    }

    private func presentReportDetails(reason: String) {
        let alert = UIAlertController(title: "Report Conversation", message: "Add any details that will help our review team.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Optional details"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self, weak alert] _ in
            guard let self, let otherUserId = self.otherUserId else { return }
            let details = alert?.textFields?.first?.text
            Task {
                do {
                    try await self.safetyService.reportConversation(
                        otherUserId: otherUserId,
                        otherDisplayName: self.otherParticipantDisplayName,
                        conversationId: self.conversation?.id,
                        itemId: self.itemId,
                        reason: reason,
                        details: details
                    )
                    await MainActor.run {
                        self.presentInfo("Report Sent", message: "Thanks. Our team will review this conversation.")
                    }
                } catch {
                    await MainActor.run {
                        self.presentError(error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func confirmBlockUser(userId: String) {
        let displayName = otherParticipantDisplayName ?? "this user"
        let alert = UIAlertController(
            title: "Block \(displayName)?",
            message: "Their chat and listings will be hidden immediately.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.safetyService.block(userId: userId, displayName: self.otherParticipantDisplayName ?? "User")
            self.applySafetyState()
            self.presentInfo("User Blocked", message: "This conversation is now hidden from your account.")
        })
        present(alert, animated: true)
    }

    private func presentInfo(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Realtime

    private func subscribeRealtime(conversationId: String) async {
        // Clean previous
        await unsubscribeRealtime()

        let client = SupabaseManager.shared.client
        let channel = client.realtimeV2.channel("chat-\(conversationId)")

        // INSERT stream for new messages
        let insertStream = channel.postgresChange(InsertAction.self, schema: "public", table: "chat_messages", filter: "conversation_id=eq.\(conversationId)")

        Task { [weak self] in
            guard let self else { return }
            for await insert in insertStream {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let msg = try insert.decodeRecord(as: ChatMessage.self, decoder: decoder)

                    // Ignore messages we already have (simple check by id)
                    let alreadyExists = await MainActor.run {
                        self.messages.contains(where: { $0.id == msg.id })
                    }
                    if alreadyExists { continue }

                    await MainActor.run {
                        debugLog("[Chat] Realtime insert received")
                        self.messages.append(msg)
                        self.tableView.reloadData()
                        self.scrollToBottom(animated: true)
                    }

                    // If the message is from the other participant, mark as read
                    let me = await MainActor.run { self.currentUserId }
                    if let me, msg.sender_id.lowercased() != me.lowercased() {
                        try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: conversationId)
                    }
                } catch {
                    // ignore decode errors
                }
            }
        }

        do {
            try await channel.subscribeWithError()
            self.realtimeChannel = channel
            await MainActor.run { self.stopPeriodicRefresh() }
        } catch {
            debugLog("[Chat] Realtime subscribe failed: \(error)")
            await MainActor.run {
                self.showStatusBanner("Live updates unavailable. Messages will appear shortly.")
                self.startPeriodicRefresh(conversationId: conversationId)
            }
        }
    }

    private func unsubscribeRealtime() async {
        if let ch = realtimeChannel {
            await ch.unsubscribe()
            realtimeChannel = nil
        }
    }

    private func startPeriodicRefresh(conversationId: String) {
        stopPeriodicRefresh()
        periodicRefreshTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    let fresh = try await ChatServiceV2.shared.fetchMessages(conversationId: conversationId)
                    await MainActor.run {
                        // Only update if there are new messages
                        if fresh.count != self.messages.count {
                            debugLog("[Chat] Periodic refresh updated message count to \(fresh.count)")
                            self.messages = fresh
                            self.tableView.reloadData()
                            self.scrollToBottom(animated: true)
                        }
                    }
                } catch {
                    // ignore
                }
            }
        }
    }

    private func stopPeriodicRefresh() {
        periodicRefreshTimer?.invalidate()
        periodicRefreshTimer = nil
    }

    @objc private func copyConversationId() {
        guard let id = conversation?.id else { return }
        UIPasteboard.general.string = id
        showStatusBanner("Conversation ID copied")
    }

    // Minimal banner
    private func showStatusBanner(_ message: String) {
        let banner = UILabel()
        banner.text = message
        banner.textAlignment = .center
        banner.backgroundColor = .systemYellow
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            banner.heightAnchor.constraint(equalToConstant: 44)
        ])

        UIView.animate(withDuration: 0.3, animations: {
            banner.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                banner.alpha = 0
            }) { _ in
                banner.removeFromSuperview()
            }
        }
    }
}

// MARK: - UITableViewDataSource/Delegate
extension ChatThreadViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BubbleCell.reuseID, for: indexPath) as? BubbleCell else {
            assertionFailure("Could not dequeue BubbleCell")
            return UITableViewCell()
        }
        guard indexPath.row < messages.count else {
            cell.configure(text: "", isCurrentUser: false)
            return cell
        }
        let msg = messages[indexPath.row]
        let isMe = (msg.sender_id.lowercased() == (currentUserId?.lowercased() ?? ""))
        cell.configure(text: msg.text, isCurrentUser: isMe)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        60
    }
}

// MARK: - UITextFieldDelegate
extension ChatThreadViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - BubbleCell
private final class BubbleCell: UITableViewCell {
    static let reuseID = "BubbleCell"

    private let bubble = UIView()
    private let label = UILabel()
    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 12
        bubble.layer.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)

        contentView.addSubview(bubble)
        bubble.addSubview(label)

        leading = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailing = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8)
        ])
    }

    func configure(text: String, isCurrentUser: Bool) {
        label.text = text
        if isCurrentUser {
            bubble.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
            label.textColor = .white
            leading.isActive = false
            trailing.isActive = true
        } else {
            bubble.backgroundColor = UIColor.systemGray5
            label.textColor = .label
            trailing.isActive = false
            leading.isActive = true
        }
        layoutIfNeeded()
    }
}

// MARK: - Safe open helper
extension ChatThreadViewController {
    // Use this from anywhere to guarantee correct pairing.
    // - If caller is borrower (not owner), you can pass only itemId; we'll resolve owner and set otherUserId.
    // - If caller is owner, you must pass borrowerId as otherUserId; if missing, we'll alert and do nothing.
    static func open(from presentingVC: UIViewController, itemId: String, otherUserId: String? = nil) {
        debugLog("[ChatThread.open] Opening chat flow")
        
        Task {
            guard let me = await SupabaseManager.shared.currentUserId() else {
                debugLog("[ChatThread.open] Refused chat open while signed out")
                await MainActor.run {
                    let ac = UIAlertController(title: "Chat", message: "Please sign in to chat.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    presentingVC.present(ac, animated: true)
                }
                return
            }

            // Resolve item owner
            struct OwnerDTO: Decodable { let owner_id: String }
            do {
                let resp = try await SupabaseManager.shared.client
                    .from("items")
                    .select("owner_id")
                    .eq("id", value: itemId)
                    .single()
                    .execute()
                let owner = try JSONDecoder().decode(OwnerDTO.self, from: resp.data).owner_id

                let vc = ChatThreadViewController()
                vc.itemId = itemId

                if me.lowercased() == owner.lowercased() {
                    debugLog("[ChatThread.open] Owner flow")
                    // Current user is owner → must have a borrower id
                    guard let borrower = otherUserId, !borrower.isEmpty, borrower.lowercased() != me.lowercased() else {
                        debugLog("[ChatThread.open] Missing borrower for owner flow")
                        await MainActor.run {
                            let ac = UIAlertController(title: "Chat", message: "Borrower not specified for this item.", preferredStyle: .alert)
                            ac.addAction(UIAlertAction(title: "OK", style: .default))
                            presentingVC.present(ac, animated: true)
                        }
                        return
                    }
                    vc.otherUserId = borrower
                } else {
                    debugLog("[ChatThread.open] Borrower flow")
                    // Current user is borrower → other = owner
                    vc.otherUserId = owner
                }

                if CommunitySafetyService.shared.isBlocked(vc.otherUserId) {
                    await MainActor.run {
                        let ac = UIAlertController(
                            title: "User Blocked",
                            message: "You blocked this user. Unblock them in Privacy & Security to chat again.",
                            preferredStyle: .alert
                        )
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        presentingVC.present(ac, animated: true)
                    }
                    return
                }

                await MainActor.run {
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    presentingVC.present(nav, animated: true)
                }
            } catch {
                debugLog("[ChatThread.open] Unable to fetch item owner: \(error)")
                await MainActor.run {
                    let ac = UIAlertController(title: "Chat", message: "Unable to open chat for this item.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    presentingVC.present(ac, animated: true)
                }
            }
        }
    }
}
