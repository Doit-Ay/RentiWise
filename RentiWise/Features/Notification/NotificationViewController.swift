//
//  NotificationViewController.swift
//  RentiWise
//
//  Created by admin99 on 07/12/25.
//

import UIKit
import Supabase

class NotificationViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    
    private var notifications: [NotificationItem] = []
    private let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Notifications"
        view.backgroundColor = .systemGroupedBackground
        
        setupTableView()
        setupEmptyState()
        
        Task {
            await loadNotifications()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationFeedUpdated),
            name: .notificationsDidUpdate,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh notifications when screen appears
        Task {
            await loadNotifications()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(NotificationCell.self, forCellReuseIdentifier: NotificationCell.reuseID)
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func setupEmptyState() {
        emptyStateView.isHidden = true
        emptyStateLabel.text = "No notifications yet"
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .systemFont(ofSize: 16, weight: .medium)
    }
    
    @objc private func handleRefresh() {
        Task {
            await loadNotifications()
            refreshControl.endRefreshing()
        }
    }

    @objc private func handleNotificationFeedUpdated() {
        Task {
            await loadNotifications()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadNotifications() async {
        do {
            // Get current user
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            
            // Fetch extension requests
            let extensionRequests = try await fetchExtensionRequests(for: userId)
            
            // Fetch return requests  
            let returnRequests = try await fetchReturnRequests(for: userId)

            // Fetch general notifications (accept/reject/payment/pickup)
            let generalNotifications = try await fetchGeneralNotifications(for: userId)
            
            // Combine and sort by date
            var allNotifications = extensionRequests + returnRequests + generalNotifications
            allNotifications.sort { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                self.notifications = allNotifications
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        } catch {
            debugLog("[Notifications] Error loading notifications: \(error)")
            await MainActor.run {
                self.updateEmptyState()
            }
        }
    }
    
    private func fetchExtensionRequests(for ownerId: String) async throws -> [NotificationItem] {
        struct ExtensionResponse: Decodable {
            let id: String
            let request_id: String
            let additional_days: Int
            let additional_cost: Double
            let created_at: String
            let is_read: Bool?
            let requests: RequestInfo
            
            struct RequestInfo: Decodable {
                let borrower_id: String
                let items: ItemInfo
            }
            
            struct ItemInfo: Decodable {
                let title: String
                let images: [String]
            }
        }
        
        let response: [ExtensionResponse] = try await SupabaseManager.shared.client
            .from("extension_requests")
            .select("""
                id,
                request_id,
                additional_days,
                additional_cost,
                created_at,
                is_read,
                requests!inner(
                    borrower_id,
                    owner_id,
                    items!inner(title, images)
                )
            """)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { ext in
            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: ext.created_at) ?? Date()
            
            return NotificationItem(
                id: ext.id,
                type: .extensionRequest,
                requestId: ext.request_id,
                itemId: nil,
                itemTitle: ext.requests.items.title,
                itemImage: ext.requests.items.images.first,
                borrowerId: ext.requests.borrower_id,
                message: "Extension request for \(ext.additional_days) days (+₹\(String(format: "%.2f", ext.additional_cost)))",
                createdAt: date,
                isRead: ext.is_read ?? false
            )
        }
    }
    
    private func fetchReturnRequests(for ownerId: String) async throws -> [NotificationItem] {
        struct ReturnResponse: Decodable {
            let id: String
            let request_id: String
            let notes: String?
            let proof_media: [String]?
            let created_at: String
            let is_read: Bool?
            let requests: RequestInfo
            
            struct RequestInfo: Decodable {
                let borrower_id: String
                let items: ItemInfo
            }
            
            struct ItemInfo: Decodable {
                let title: String
                let images: [String]
            }
        }
        
        let response: [ReturnResponse] = try await SupabaseManager.shared.client
            .from("return_requests")
            .select("""
                id,
                request_id,
                notes,
                proof_media,
                created_at,
                is_read,
                requests!inner(
                    borrower_id,
                    owner_id,
                    items!inner(title, images)
                )
            """)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { ret in
            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: ret.created_at) ?? Date()
            
            let message = ret.notes?.isEmpty == false ? 
                "Return request submitted with notes" : 
                "Return request submitted"
                
            // Always use item image for thumbnail (proof_media upload is not fully implemented)
            let itemImage = ret.requests.items.images.first
            
            return NotificationItem(
                id: ret.id,
                type: .returnRequest,
                requestId: ret.request_id,
                itemId: nil,
                itemTitle: ret.requests.items.title,
                itemImage: itemImage,
                borrowerId: ret.requests.borrower_id,
                message: message,
                createdAt: date,
                isRead: ret.is_read ?? false
            )
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !notifications.isEmpty
        tableView.isHidden = notifications.isEmpty
    }

    // MARK: - General Notifications (from notifications table)

    private func fetchGeneralNotifications(for userId: String) async throws -> [NotificationItem] {
        struct GeneralNotificationRow: Decodable {
            let id: String
            let type: String
            let title: String
            let message: String
            let request_id: String?
            let item_id: String?
            let is_read: Bool?
            let created_at: String
        }

        let response: [GeneralNotificationRow] = try await SupabaseManager.shared.client
            .from("notifications")
            .select("id, type, title, message, request_id, item_id, is_read, created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return response.map { row in
            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: row.created_at) ?? Date()

            let notifType: NotificationType
            switch row.type {
            case "request_accepted":  notifType = .requestAccepted
            case "request_rejected":  notifType = .requestRejected
            case "payment_received":  notifType = .paymentReceived
            case "payment_confirmed": notifType = .paymentConfirmed
            case "pickup_confirmed":  notifType = .pickupConfirmed
            case "new_request":       notifType = .newRequest
            case "nearby_item_posted": notifType = .nearbyItem
            default:                  notifType = .requestAccepted
            }

            return NotificationItem(
                id: row.id,
                type: notifType,
                requestId: row.request_id ?? "",
                itemId: row.item_id,
                itemTitle: row.title,
                itemImage: nil,
                borrowerId: "",
                message: row.message,
                createdAt: date,
                isRead: row.is_read ?? false
            )
        }
    }
    
    // MARK: - Mark as Read
    
    private func markAsRead(notification: NotificationItem) async {
        do {
            let tableName: String
            switch notification.type {
            case .extensionRequest:
                tableName = "extension_requests"
            case .returnRequest:
                tableName = "return_requests"
            case .requestAccepted, .requestRejected, .paymentReceived, .paymentConfirmed, .pickupConfirmed, .newRequest, .nearbyItem:
                tableName = "notifications"
            }
            
            try await SupabaseManager.shared.client
                .from(tableName)
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            // Update local state
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                await MainActor.run {
                    notifications[index].isRead = true
                    tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
            }
            NotificationCenter.default.post(name: .notificationsDidUpdate, object: nil)
        } catch {
            debugLog("[Notifications] Error marking as read: \(error)")
        }
    }
}

// MARK: - UITableViewDataSource

extension NotificationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NotificationCell.reuseID, for: indexPath) as! NotificationCell
        let notification = notifications[indexPath.row]
        cell.configure(with: notification)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension NotificationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let notification = notifications[indexPath.row]
        
        // Mark as read
        Task {
            await markAsRead(notification: notification)
        }
        
        // Navigate to appropriate screen based on notification type
        switch notification.type {
        case .extensionRequest, .returnRequest:
            openRequestApprovalScreen(for: notification)
        case .requestAccepted, .requestRejected, .paymentConfirmed, .pickupConfirmed:
            // Borrower-side notifications: open BookingApprovalVC if we have a request_id
            if !notification.requestId.isEmpty {
                openBookingApprovalScreen(requestId: notification.requestId)
            }
        case .paymentReceived, .newRequest:
            // Lender-side notifications: open the lender request detail if we have a request_id
            if !notification.requestId.isEmpty {
                openLenderRequestScreen(requestId: notification.requestId)
            }
        case .nearbyItem:
            let itemId = notification.itemId ?? notification.requestId
            if !itemId.isEmpty {
                openProductScreen(itemId: itemId)
            }
        }
    }
    
    private func openRequestApprovalScreen(for notification: NotificationItem) {
        // Create RequestApprovalViewController from XIB
        let approvalVC = RequestApprovalViewController(nibName: "RequestApprovalViewController", bundle: nil)
        
        // Determine request type
        let requestType: RequestType = notification.type == .returnRequest ? .returnRequest : .extensionRequest
        
        // Configure the view controller
        approvalVC.configure(
            requestType: requestType,
            requestId: notification.id,
            bookingId: notification.requestId
        )
        
        // Push to navigation stack
        navigationController?.pushViewController(approvalVC, animated: true)
    }

    private func openBookingApprovalScreen(requestId: String) {
        Task {
            do {
                // Fetch the request with joined item data
                let response = try await SupabaseManager.shared.client
                    .from("requests")
                    .select("""
                        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,
                        items(id,title,images,price_per_day,category)
                    """)
                    .eq("id", value: requestId)
                    .single()
                    .execute()

                let request = try JSONDecoder().decode(RequestWithItem.self, from: response.data)

                await MainActor.run {
                    let nibName = "BookingApprovalViewController"
                    let bookingVC: BookingApprovalViewController
                    if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                        Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                        bookingVC = BookingApprovalViewController(nibName: nibName, bundle: nil)
                    } else {
                        bookingVC = BookingApprovalViewController()
                    }
                    bookingVC.request = request
                    bookingVC.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(bookingVC, animated: true)
                }
            } catch {
                debugLog("[Notifications] Error opening booking: \(error)")
            }
        }
    }

    private func openLenderRequestScreen(requestId: String) {
        Task {
            do {
                let select: String
                if RequestSchemaSupport.supportsPickupCode {
                    select = """
                        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,pickup_code,
                        items(id,title,images,price_per_day,category)
                    """
                } else {
                    select = """
                        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,return_time,rental_unit,status,created_at,
                        items(id,title,images,price_per_day,category)
                    """
                }

                let response = try await SupabaseManager.shared.client
                    .from("requests")
                    .select(select)
                    .eq("id", value: requestId)
                    .single()
                    .execute()

                let request = try JSONDecoder().decode(RequestWithItem.self, from: response.data)

                await MainActor.run {
                    let vc = DashboardLenderRequestViewController(
                        nibName: "DashboardLenderRequestViewController",
                        bundle: nil
                    )
                    vc.request = request
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } catch {
                if RequestSchemaSupport.isMissingPickupCodeError(error), RequestSchemaSupport.supportsPickupCode {
                    RequestSchemaSupport.markPickupCodeUnavailable()
                    self.openLenderRequestScreen(requestId: requestId)
                    return
                }
                debugLog("[Notifications] Error opening lender request: \(error)")
            }
        }
    }

    private func openProductScreen(itemId: String) {
        Task {
            do {
                let response = try await SupabaseManager.shared.client
                    .from("items")
                    .select()
                    .eq("id", value: itemId)
                    .single()
                    .execute()

                let item = try JSONDecoder().decode(Item.self, from: response.data)
                await MainActor.run {
                    let vc = ProductViewController(nibName: "ProductViewController", bundle: nil)
                    vc.configure(with: item)
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } catch {
                debugLog("[Notifications] Error opening item from notification: \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
}

// MARK: - Supporting Types

struct NotificationItem {
    let id: String
    let type: NotificationType
    let requestId: String
    let itemId: String?
    let itemTitle: String
    let itemImage: String?
    let borrowerId: String
    let message: String
    let createdAt: Date
    var isRead: Bool
}

enum NotificationType {
    case extensionRequest
    case returnRequest
    case requestAccepted
    case requestRejected
    case paymentReceived
    case paymentConfirmed
    case pickupConfirmed
    case newRequest
    case nearbyItem
    
    var icon: String {
        switch self {
        case .extensionRequest:  return "clock.arrow.circlepath"
        case .returnRequest:     return "checkmark.circle"
        case .requestAccepted:   return "hand.thumbsup.fill"
        case .requestRejected:   return "hand.thumbsdown.fill"
        case .paymentReceived:   return "indianrupeesign.circle.fill"
        case .paymentConfirmed:  return "checkmark.seal.fill"
        case .pickupConfirmed:   return "shippingbox.fill"
        case .newRequest:        return "bell.badge.fill"
        case .nearbyItem:        return "location.circle.fill"
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .extensionRequest:
            return UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0) // Teal
        case .returnRequest:
            return UIColor.systemGreen
        case .requestAccepted:
            return UIColor.systemGreen
        case .requestRejected:
            return UIColor.systemRed
        case .paymentReceived:
            return UIColor.systemOrange
        case .paymentConfirmed:
            return UIColor.systemGreen
        case .pickupConfirmed:
            return UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0)
        case .newRequest:
            return UIColor.systemBlue
        case .nearbyItem:
            return UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0)
        }
    }
}

// MARK: - Custom Cell

class NotificationCell: UITableViewCell {
    static let reuseID = "NotificationCell"
    
    private let containerView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadIndicator = UIView()
    private let itemImageView = UIImageView()
    private var imageLoadTask: URLSessionDataTask?
    private var currentImageURL: String?  // track which URL this cell is loading
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentImageURL = nil
        itemImageView.image = nil
        titleLabel.text = nil
        messageLabel.text = nil
        timeLabel.text = nil
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Container with white background and shadow
        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowRadius = 4
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(containerView)
        
        // Item image
        itemImageView.contentMode = .scaleAspectFill
        itemImageView.clipsToBounds = true
        itemImageView.layer.cornerRadius = 8
        itemImageView.backgroundColor = .tertiarySystemGroupedBackground
        containerView.addSubview(itemImageView)
        
        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemBlue
        containerView.addSubview(iconView)
        
        // Title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        // Message
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 2
        containerView.addSubview(messageLabel)
        
        // Time
        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .tertiaryLabel
        containerView.addSubview(timeLabel)
        
        // Unread indicator
        unreadIndicator.backgroundColor = UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0)
        unreadIndicator.layer.cornerRadius = 4
        containerView.addSubview(unreadIndicator)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        itemImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            // Item image
            itemImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            itemImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            itemImageView.widthAnchor.constraint(equalToConstant: 60),
            itemImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Icon (overlaid on item image)
            iconView.trailingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: -4),
            iconView.bottomAnchor.constraint(equalTo: itemImageView.bottomAnchor, constant: -4),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: itemImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: unreadIndicator.leadingAnchor, constant: -8),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Time
            timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Unread indicator
            unreadIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            unreadIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            unreadIndicator.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicator.heightAnchor.constraint(equalToConstant: 8),
        ])
    }
    
    func configure(with notification: NotificationItem) {
        titleLabel.text = notification.itemTitle
        messageLabel.text = notification.message
        timeLabel.text = notification.createdAt.timeAgoDisplay()
        
        // Icon
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconView.image = UIImage(systemName: notification.type.icon, withConfiguration: config)
        iconView.tintColor = notification.type.iconColor
        
        // Unread indicator
        unreadIndicator.isHidden = notification.isRead
        
        // Item image — use StorageURLBuilder to build the full URL
        if let imagePath = notification.itemImage,
           let url = StorageURLBuilder.publicFileURL(for: imagePath) {
            let urlString = url.absoluteString
            currentImageURL = urlString
            imageLoadTask?.cancel()
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            imageLoadTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else {
                    DispatchQueue.main.async {
                        guard self?.currentImageURL == urlString else { return }
                        self?.itemImageView.image = UIImage(systemName: "photo")
                        self?.itemImageView.tintColor = .tertiaryLabel
                        self?.itemImageView.contentMode = .scaleAspectFit
                    }
                    return
                }
                DispatchQueue.main.async {
                    guard self?.currentImageURL == urlString else { return }
                    self?.itemImageView.image = image
                    self?.itemImageView.contentMode = .scaleAspectFill
                }
            }
            imageLoadTask?.resume()
        } else {
            currentImageURL = nil
            itemImageView.image = UIImage(systemName: "photo")
            itemImageView.tintColor = .tertiaryLabel
            itemImageView.contentMode = .scaleAspectFit
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
