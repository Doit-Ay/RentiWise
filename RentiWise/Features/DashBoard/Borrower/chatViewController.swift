//
//  chatViewController.swift
//  RentiWise
//
//  Created by admin99 on 19/01/26.
//

import UIKit

final class ChatThreadViewController: UIViewController {

    // Context passed by caller
    var otherUserId: String?
    var itemId: String?

    // Simple in-memory messages for now
    private struct Message {
        let id: String
        let senderId: String
        let text: String
        let date: Date
    }
    private var messages: [Message] = []

    // Current user id (no subtitle usage to avoid iOS version API issues)
    private var currentUserId: String?

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)

    private var inputBottomConstraint: NSLayoutConstraint?

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

        // Load current user id (async); for now mock as non-nil so bubble alignment works
        Task {
            let uid = await SupabaseManager.shared.currentUserId()
            await MainActor.run {
                self.currentUserId = uid ?? "me"
                self.loadInitialMessages()
            }
        }
    }

    @objc private func closeTapped() {
        // Dismiss the modal chat flow
        dismiss(animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    private func loadInitialMessages() {
        // Seed with a couple of sample messages
        let me = currentUserId ?? "me"
        let other = otherUserId ?? "other"

        messages = [
            Message(id: UUID().uuidString, senderId: other, text: "Hi! Thanks for your interest.", date: Date().addingTimeInterval(-3600)),
            Message(id: UUID().uuidString, senderId: me, text: "Hello! Is the item available tomorrow?", date: Date().addingTimeInterval(-3500))
        ]
        tableView.reloadData()
        scrollToBottom(animated: false)
    }

    @objc private func sendTapped() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        let me = currentUserId ?? "me"
        let msg = Message(id: UUID().uuidString, senderId: me, text: text, date: Date())
        inputField.text = nil
        messages.append(msg)
        tableView.reloadData()
        scrollToBottom(animated: true)

        // TODO: Send to backend (Supabase) with otherUserId and itemId context
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let last = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
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
        let isMe = msg.senderId == (currentUserId ?? "")
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
