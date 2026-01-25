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
    var otherUserId: String?
    var itemId: String?

    // Backend models
    private var conversation: ChatConversation?
    private var messages: [ChatMessage] = []

    // Current user id
    private var currentUserId: String?

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBottomConstraint: NSLayoutConstraint?

    // Realtime channel
    private var realtimeChannel: RealtimeChannelV2?

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

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { await unsubscribeRealtime() }
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
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Backend wiring

    private func bootstrapConversationAndLoad() async {
        // Resolve user
        let uid = await SupabaseManager.shared.currentUserId()
        await MainActor.run { self.currentUserId = uid }

        guard let other = otherUserId else {
            await MainActor.run {
                self.presentError("Missing other user.")
            }
            return
        }

        do {
            // Get or create conversation
            let convo = try await ChatServiceV2.shared.getOrCreateConversation(withUserId: other, itemId: itemId)
            await MainActor.run {
                self.conversation = convo
            }

            // Load messages
            let loaded = try await ChatServiceV2.shared.fetchMessages(conversationId: convo.id)
            await MainActor.run {
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
            guard let convoId = conversation?.id else { return }

            // Optimistic UI: clear input immediately
            await MainActor.run { self.inputField.text = nil }

            do {
                let sent = try await ChatServiceV2.shared.sendMessage(conversationId: convoId, text: text)
                await MainActor.run {
                    self.messages.append(sent)
                    self.tableView.reloadData()
                    self.scrollToBottom(animated: true)
                }
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
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    private func presentError(_ message: String) {
        let ac = UIAlertController(title: "Chat Error", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Realtime

    private func subscribeRealtime(conversationId: String) async {
        // Clean previous
        await unsubscribeRealtime()

        let client = SupabaseManager.shared.client
        let channel = client.realtimeV2.channel("chat-\(conversationId)")
        // Listen for Postgres INSERTs on chat_messages for this conversation
        let stream = channel.postgresChange(InsertAction.self, schema: "public", table: "chat_messages", filter: "conversation_id=eq.\(conversationId)")

        Task.detached { [weak self] in
            guard let self else { return }
            for await insert in stream {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let msg = try insert.decodeRecord(as: ChatMessage.self, decoder: decoder)

                    // Ignore messages we already have (simple check by id)
                    if self.messages.contains(where: { $0.id == msg.id }) { continue }

                    await MainActor.run {
                        self.messages.append(msg)
                        self.tableView.reloadData()
                        self.scrollToBottom(animated: true)
                    }
                } catch {
                    // ignore decode errors
                }
            }
        }

        do {
            try await channel.subscribeWithError()
            self.realtimeChannel = channel
        } catch {
            // Fallback: no realtime; chat still works with manual refresh
        }
    }

    private func unsubscribeRealtime() async {
        if let ch = realtimeChannel {
            await ch.unsubscribe()
            realtimeChannel = nil
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
        let isMe = (currentUserId != nil) ? (msg.sender_id == currentUserId!) : false
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
            leading, trailing,
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

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
