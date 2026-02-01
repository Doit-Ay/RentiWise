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
        didSet { emptyStateLabel.isHidden = !messages.isEmpty }
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

        setupTable()
        setupInputBar()
        observeKeyboard()

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
        Task { await unsubscribeRealtime() }
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

        print("[Chat] open params -> me=\(me) other=\(other ?? "nil") itemId=\(item ?? "nil")")

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

        do {
            // Require itemId to ensure correct lender/borrower pairing
            let convo = try await ChatServiceV2.shared.getOrCreateConversation(withUserId: other, itemId: item)
            await MainActor.run {
                self.conversation = convo
                print("[Chat] conversation id=\(convo.id) item=\(convo.item_id ?? "nil") lender=\(convo.lender_id) borrower=\(convo.borrower_id)")
            }

            // Load messages
            let loaded = try await ChatServiceV2.shared.fetchMessages(conversationId: convo.id)
            await MainActor.run {
                print("[Chat] loaded messages count=\(loaded.count)")
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
                    print("[Chat] sent message id=\(sent.id) convo=\(sent.conversation_id)")
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

    // MARK: - Realtime

    private func subscribeRealtime(conversationId: String) async {
        // Clean previous
        await unsubscribeRealtime()

        let client = SupabaseManager.shared.client
        let channel = client.realtimeV2.channel("chat-\(conversationId)")

        // INSERT stream for new messages
        let insertStream = channel.postgresChange(InsertAction.self, schema: "public", table: "chat_messages", filter: "conversation_id=eq.\(conversationId)")

        Task.detached { [weak self] in
            guard let self else { return }
            for await insert in insertStream {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let msg = try insert.decodeRecord(as: ChatMessage.self, decoder: decoder)

                    // Ignore messages we already have (simple check by id)
                    if self.messages.contains(where: { $0.id == msg.id }) { continue }

                    await MainActor.run {
                        print("[Chat] realtime insert id=\(msg.id)")
                        self.messages.append(msg)
                        self.tableView.reloadData()
                        self.scrollToBottom(animated: true)
                    }

                    // If the message is from the other participant, mark as read
                    if let me = self.currentUserId, msg.sender_id.lowercased() != me.lowercased() {
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
            print("[Chat] Realtime subscribe failed for conversation=\(conversationId): \(error)")
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
                            print("[Chat] periodic refresh updated \(fresh.count) messages")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: BubbleCell.reuseID, for: indexPath) as! BubbleCell
        let msg = messages[indexPath.row]
        let isMe = (currentUserId != nil) ? (msg.sender_id.lowercased() == currentUserId!.lowercased()) : false
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
            bubble.backgroundColor = UIColor.systemBlue
            label.textColor = .white
            leading.isActive = false
            trailing.isActive = true
        } else {
            bubble.backgroundColor = UIColor.secondarySystemBackground
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
        print("[ChatThread.open] itemId=\(itemId), otherUserId=\(otherUserId ?? "nil")")
        
        Task {
            guard let me = await SupabaseManager.shared.currentUserId() else {
                print("[ChatThread.open] ERROR: Not signed in")
                await MainActor.run {
                    let ac = UIAlertController(title: "Chat", message: "Please sign in to chat.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    presentingVC.present(ac, animated: true)
                }
                return
            }
            
            print("[ChatThread.open] Current user: \(me)")

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
                
                print("[ChatThread.open] Item owner: \(owner)")

                let vc = ChatThreadViewController()
                vc.itemId = itemId

                if me.lowercased() == owner.lowercased() {
                    print("[ChatThread.open] Current user IS the owner")
                    // Current user is owner → must have a borrower id
                    guard let borrower = otherUserId, !borrower.isEmpty, borrower.lowercased() != me.lowercased() else {
                        print("[ChatThread.open] ERROR: Borrower not specified or invalid. otherUserId=\(otherUserId ?? "nil")")
                        await MainActor.run {
                            let ac = UIAlertController(title: "Chat", message: "Borrower not specified for this item.", preferredStyle: .alert)
                            ac.addAction(UIAlertAction(title: "OK", style: .default))
                            presentingVC.present(ac, animated: true)
                        }
                        return
                    }
                    vc.otherUserId = borrower
                    print("[ChatThread.open] Setting otherUserId=\(borrower) (borrower)")
                } else {
                    print("[ChatThread.open] Current user is NOT the owner - they are borrower")
                    // Current user is borrower → other = owner
                    vc.otherUserId = owner
                    print("[ChatThread.open] Setting otherUserId=\(owner) (owner)")
                }

                await MainActor.run {
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    presentingVC.present(nav, animated: true)
                }
            } catch {
                print("[ChatThread.open] ERROR: Unable to fetch item owner - \(error)")
                await MainActor.run {
                    let ac = UIAlertController(title: "Chat", message: "Unable to open chat for this item.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    presentingVC.present(ac, animated: true)
                }
            }
        }
    }
}
