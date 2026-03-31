import Foundation

struct BlockedUser: Codable, Hashable {
    let id: String
    let displayName: String
    let blockedAt: Date
}

final class CommunitySafetyService {
    static let shared = CommunitySafetyService()
    static let blockedUsersDidChangeNotification = Notification.Name("CommunitySafetyService.blockedUsersDidChange")

    private let supportService: SupportChatServicing
    private let defaults: UserDefaults

    private var blockedUsersKey: String? {
        guard let scope = SupabaseManager.shared.currentUserIdSync()?.lowercased(), !scope.isEmpty else {
            return nil
        }
        return "communitySafety.blockedUsers.\(scope)"
    }

    init(
        supportService: SupportChatServicing = SupportChatService(),
        defaults: UserDefaults = .standard
    ) {
        self.supportService = supportService
        self.defaults = defaults
    }

    func blockedUsers() -> [BlockedUser] {
        guard let blockedUsersKey, let data = defaults.data(forKey: blockedUsersKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let users = try? decoder.decode([BlockedUser].self, from: data) {
            return users.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        return []
    }

    func blockedUserIds() -> Set<String> {
        Set(blockedUsers().map { normalize($0.id) })
    }

    func isBlocked(_ userId: String?) -> Bool {
        guard let userId else { return false }
        return blockedUserIds().contains(normalize(userId))
    }

    func block(userId: String, displayName: String) {
        mutateBlockedUsers { users in
            let normalizedId = normalize(userId)
            users.removeAll { normalize($0.id) == normalizedId }
            users.append(BlockedUser(id: userId, displayName: displayName, blockedAt: Date()))
        }
    }

    func unblock(userId: String) {
        mutateBlockedUsers { users in
            let normalizedId = normalize(userId)
            users.removeAll { normalize($0.id) == normalizedId }
        }
    }

    func clearLocalState() {
        if let blockedUsersKey {
            defaults.removeObject(forKey: blockedUsersKey)
        }
        NotificationCenter.default.post(name: Self.blockedUsersDidChangeNotification, object: nil)
    }

    func visibleItems(from items: [Item]) -> [Item] {
        let blockedIds = blockedUserIds()
        guard !blockedIds.isEmpty else { return items }
        return items.filter { !blockedIds.contains(normalize($0.owner_id)) }
    }

    func reportListing(
        item: Item,
        ownerDisplayName: String?,
        reason: String,
        details: String?
    ) async throws {
        let subject = "[Safety] Listing report: \(truncate(item.title, limit: 48))"
        let body = """
        Report type: Listing
        Reason: \(reason)
        Listing ID: \(item.id)
        Listing title: \(item.title)
        Owner ID: \(item.owner_id)
        Owner name: \(ownerDisplayName ?? "Unknown")

        Details:
        \(normalizedDetails(details))
        """
        _ = try await supportService.createSupportTicket(subject: subject, message: body)
    }

    func reportUser(
        userId: String,
        displayName: String?,
        context: String,
        reason: String,
        details: String?
    ) async throws {
        let subject = "[Safety] User report: \(truncate(displayName ?? userId, limit: 48))"
        let body = """
        Report type: User
        Reason: \(reason)
        User ID: \(userId)
        User name: \(displayName ?? "Unknown")
        Context: \(context)

        Details:
        \(normalizedDetails(details))
        """
        _ = try await supportService.createSupportTicket(subject: subject, message: body)
    }

    func reportConversation(
        otherUserId: String,
        otherDisplayName: String?,
        conversationId: String?,
        itemId: String?,
        reason: String,
        details: String?
    ) async throws {
        let subject = "[Safety] Chat report: \(truncate(otherDisplayName ?? otherUserId, limit: 48))"
        let body = """
        Report type: Conversation
        Reason: \(reason)
        Other user ID: \(otherUserId)
        Other user name: \(otherDisplayName ?? "Unknown")
        Conversation ID: \(conversationId ?? "Unavailable")
        Item ID: \(itemId ?? "Unavailable")

        Details:
        \(normalizedDetails(details))
        """
        _ = try await supportService.createSupportTicket(subject: subject, message: body)
    }

    private func mutateBlockedUsers(_ mutate: (inout [BlockedUser]) -> Void) {
        guard let blockedUsersKey else {
            NotificationCenter.default.post(name: Self.blockedUsersDidChangeNotification, object: nil)
            return
        }

        var users = blockedUsers()
        mutate(&users)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(users) {
            defaults.set(data, forKey: blockedUsersKey)
        } else {
            defaults.removeObject(forKey: blockedUsersKey)
        }

        NotificationCenter.default.post(name: Self.blockedUsersDidChangeNotification, object: nil)
    }

    private func normalize(_ userId: String) -> String {
        userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedDetails(_ details: String?) -> String {
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No additional details provided." : trimmed
    }

    private func truncate(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit - 1)) + "…"
    }
}
