import Foundation

enum SafetyContentViolation: LocalizedError, Equatable {
    case restrictedListingTerm(String)
    case restrictedMessage
    case messageRateLimited(secondsRemaining: Int)

    var errorDescription: String? {
        switch self {
        case .restrictedListingTerm(let term):
            return "This listing includes a restricted term (\(term)). Please remove prohibited or unsafe item details before publishing."
        case .restrictedMessage:
            return "That message includes restricted language. Please edit it and try again."
        case .messageRateLimited(let secondsRemaining):
            return "You're sending messages too quickly. Please wait about \(max(1, secondsRemaining)) seconds and try again."
        }
    }
}

enum SafetyContentPolicy {
    private static let restrictedListingTerms = [
        "gun",
        "firearm",
        "rifle",
        "shotgun",
        "pistol",
        "ammo",
        "ammunition",
        "weapon",
        "grenade",
        "drug",
        "drugs",
        "marijuana",
        "weed",
        "cocaine",
        "heroin",
        "narcotic",
        "counterfeit",
        "fake branded",
        "stolen"
    ]

    private static let restrictedMessageTerms = [
        "kill you",
        "hurt you",
        "weapon",
        "gun",
        "firearm",
        "drug",
        "counterfeit"
    ]

    static func validateListing(_ draft: AddItemDraft) throws {
        if let term = firstMatchedTerm(
            in: [
                draft.title,
                draft.description,
                draft.category,
                draft.condition
            ],
            restrictedTerms: restrictedListingTerms
        ) {
            throw SafetyContentViolation.restrictedListingTerm(term)
        }
    }

    static func validateChatMessage(_ text: String) throws {
        if firstMatchedTerm(in: [text], restrictedTerms: restrictedMessageTerms) != nil {
            throw SafetyContentViolation.restrictedMessage
        }
    }

    static func containsRestrictedListingContent(title: String, description: String, category: String, condition: String) -> Bool {
        firstMatchedTerm(in: [title, description, category, condition], restrictedTerms: restrictedListingTerms) != nil
    }

    private static func firstMatchedTerm(in values: [String], restrictedTerms: [String]) -> String? {
        for value in values {
            let normalized = " " + value.lowercased() + " "
            for term in restrictedTerms {
                let escaped = NSRegularExpression.escapedPattern(for: term.lowercased())
                let pattern = "(^|[^a-z0-9])\(escaped)([^a-z0-9]|$)"
                if normalized.range(of: pattern, options: .regularExpression) != nil {
                    return term
                }
            }
        }
        return nil
    }
}

actor ChatMessageRateLimiter {
    static let shared = ChatMessageRateLimiter()

    private let limit = 20
    private let window: TimeInterval = 60
    private var timestampsByConversation: [String: [Date]] = [:]

    func registerSend(for conversationId: String, now: Date = Date()) throws {
        let cutoff = now.addingTimeInterval(-window)
        var timestamps = timestampsByConversation[conversationId, default: []]
            .filter { $0 >= cutoff }

        guard timestamps.count < limit else {
            let oldestAllowed = timestamps.first?.addingTimeInterval(window) ?? now.addingTimeInterval(window)
            let remaining = Int(ceil(max(1, oldestAllowed.timeIntervalSince(now))))
            throw SafetyContentViolation.messageRateLimited(secondsRemaining: remaining)
        }

        timestamps.append(now)
        timestampsByConversation[conversationId] = timestamps
    }
}
