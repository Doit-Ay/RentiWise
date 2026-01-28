//
//  ChatViewController.swift
//  RentiWise
//
//  P2P Chat View Controller with Realtime updates
//

import UIKit
import Supabase

class ChatViewController: UIViewController {

    // MARK: - Properties
    
    // Set these when navigating to this controller
    var otherUserId: String?
    var otherUserName: String?
    var itemId: String? // Optional: if chatting about a specific item
    
    private var conversation: ChatConversation?
    private var messages: [ChatMessage] = []
    private var currentUserId: String?
    private var realtimeChannel: RealtimeChannelV2?
    private var pollingTimer: Timer?
    
    // MARK: - UI Elements
    // ... (UI Elements remain same)

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        
        if let name = otherUserName {
            title = name
        } else {
            title = "Chat"
        }
        
        setupUI()
        setupKeyboardObservers()
        loadData()
        startPolling()
    }
    
    deinit {
        pollingTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }
    
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkForNewMessages()
        }
    }
    
    private func checkForNewMessages() {
        guard let conversationId = conversation?.id else { return }
        Task {
            do {
                // Fetch latest 20 messages to check for new ones
                // Ideally we would fetch "after date", but fetching last 20 is a safe simple fallback
                let latest = try await ChatServiceV2.shared.fetchMessages(conversationId: conversationId, limit: 20)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    var hasNew = false
                    for msg in latest {
                        if !self.messages.contains(where: { $0.id == msg.id }) {
                            self.messages.append(msg)
                            hasNew = true
                        }
                    }
                    
                    if hasNew {
                        self.messages.sort(by: { $0.created_at < $1.created_at })
                        self.tableView.reloadData()
                        self.scrollToBottom()
                        try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: conversationId)
                    }
                }
            } catch {
                // Polling error, ignore
            }
        }
    }
    
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0) // App theme background
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        tv.dataSource = self
        tv.delegate = self
        tv.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseIdentifier)
        return tv
    }()
    
    private let inputContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white // Input area background
        return view
    }()
    
    private let inputTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Type a message..."
        tf.font = .systemFont(ofSize: 16)
        tf.borderStyle = .none
        tf.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        tf.layer.cornerRadius = 20
        tf.layer.masksToBounds = true
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        
        return tf
    }()
    
    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        // Using "paperplane.fill" or similar icon
        btn.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        btn.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0) // App Theme Color
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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        
        if let name = otherUserName {
            title = name
        } else {
            title = "Chat"
        }
        
        setupUI()
        setupKeyboardObservers()
        loadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)
        view.addSubview(loadingIndicator)
        
        inputContainerBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            // TableView
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),
            
            // Input Container
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerBottomConstraint,
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Text Field
            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            
            // Send Button
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Loading
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tableView.addGestureRecognizer(tap)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        guard let otherId = otherUserId else { return }
        loadingIndicator.startAnimating()
        
        Task {
            currentUserId = await SupabaseManager.shared.currentUserId()
            
            do {
                // Get or create conversation
                let convo = try await ChatServiceV2.shared.getOrCreateConversation(withUserId: otherId, itemId: itemId)
                self.conversation = convo
                
                // Fetch previous messages
                let initialMessages = try await ChatServiceV2.shared.fetchMessages(conversationId: convo.id)
                
                await MainActor.run {
                    self.messages = initialMessages
                    self.loadingIndicator.stopAnimating()
                    self.tableView.reloadData()
                    self.scrollToBottom()
                    self.subscribeToConversation(convo.id)
                }
                
                // Mark as read
                try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: convo.id)
                
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    // Handle error (alert)
                }
            }
        }
    }
    
    private func subscribeToConversation(_ conversationId: String) {
        realtimeChannel = ChatServiceV2.shared.subscribeToMessages(conversationId: conversationId) { [weak self] message in
            guard let self = self else { return }
            Task { @MainActor in
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    self.tableView.reloadData()
                    self.scrollToBottom()
                    
                    if let currentUserId = self.currentUserId, message.sender_id != currentUserId {
                         try? await ChatServiceV2.shared.markMessagesAsRead(conversationId: conversationId)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func sendButtonTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let conversationId = conversation?.id else { return }
        
        inputTextField.text = ""
        
        Task {
            do {
                let sentMessage = try await ChatServiceV2.shared.sendMessage(conversationId: conversationId, text: text)
                // The realtime subscription will likely catch this back, but we can append it optimistically or just wait.
                // Since our subscription logic checks for duplicates, we can append it here safely for instant feedback.
                 await MainActor.run {
                     if !self.messages.contains(where: { $0.id == sentMessage.id }) {
                         self.messages.append(sentMessage)
                         self.tableView.reloadData()
                         self.scrollToBottom()
                     }
                 }
            } catch {
                print("Error sending message: \(error)")
                // Restore text if failed?
            }
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        let keyboardHeight = frame.height - view.safeAreaInsets.bottom
        inputContainerBottomConstraint.constant = -keyboardHeight
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            self.scrollToBottom()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        inputContainerBottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseIdentifier, for: indexPath) as! ChatMessageCell
        let message = messages[indexPath.row]
        let isCurrentUser = (message.sender_id == currentUserId)
        cell.configure(with: message, isCurrentUser: isCurrentUser)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
