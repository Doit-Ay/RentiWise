//
//  ChatContentFilter.swift
//  RentiWise
//
//  Client-side content moderation filter for chat messages.
//  Blocks messages containing slurs, hate speech, or abusive language
//  before they reach the server. Required for App Store UGC compliance (Guideline 1.2).
//

import Foundation

enum ChatContentFilter {

    // MARK: - Violation Tracking

    /// Number of blocked messages in the current session.
    /// After `escalationThreshold` violations, an auto-report is triggered.
    private(set) static var sessionViolationCount: Int = 0

    /// Threshold after which the system auto-reports the user.
    static let escalationThreshold: Int = 3

    /// Returns `true` if the user has hit the auto-report threshold.
    static var shouldAutoReport: Bool {
        sessionViolationCount >= escalationThreshold
    }

    /// Call this when a message is blocked to increment violation counter.
    @discardableResult
    static func recordViolation() -> Int {
        sessionViolationCount += 1
        return sessionViolationCount
    }

    /// Reset the session counter (e.g. on sign-out or new session).
    static func resetViolationCount() {
        sessionViolationCount = 0
    }

    // MARK: - Public API

    /// Returns `nil` if the message is clean, or a user-facing reason string if it should be blocked.
    static func check(_ text: String) -> String? {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "!", with: "i")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "7", with: "t")
            // Strip repeated chars like "fuuuck" → "fuck"
            .replacingRepeatedCharacters()

        // Build word set (split on non-alpha)
        let words = normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }

        for word in words {
            if slurs.contains(word) {
                return blockedMessage
            }
        }

        // Substring scan for terms that may appear within compound words
        for term in substringBlockList {
            if normalized.contains(term) {
                return blockedMessage
            }
        }

        return nil // clean
    }

    // MARK: - Escalation message

    /// Returns an appropriate warning message based on violation count.
    static var currentWarningMessage: String {
        let count = sessionViolationCount
        if count >= escalationThreshold {
            return "Your message was blocked for prohibited language. Due to repeated violations, your account has been flagged for review. Continued violations may result in account restrictions."
        } else if count >= 2 {
            return "Your message was blocked because it contains prohibited language. Warning \(count)/\(escalationThreshold): Repeated violations will result in an automatic report to our safety team."
        } else {
            return "Your message contains language that violates our community guidelines."
        }
    }

    // MARK: - Private

    private static let blockedMessage = "Your message contains language that violates our community guidelines."

    /// Exact-match slurs and hate terms (lowercase, normalized).
    private static let slurs: Set<String> = [
        // Racial / ethnic slurs
        "nigger", "nigga", "niggas", "nigg3r", "n1gger", "n1gga",
        "chink", "chinky", "gook", "spic", "spick", "wetback", "beaner",
        "kike", "kyke", "heeb",
        "redskin", "injun",
        "coon", "darkie", "jigaboo", "sambo",
        "cracker", "honky", "gringo",
        "paki", "raghead", "towelhead", "sandnigger",
        "zipperhead",

        // Homophobic / transphobic slurs
        "faggot", "fag", "faggots", "fags", "dyke", "tranny",

        // Sexist / misogynistic terms
        "whore", "slut", "cunt", "bitch",

        // Other abusive terms
        "retard", "retarded", "tard",

        // Threats / violence keywords
        "killurself", "killyourself", "rapeyou",

        // Hindi / Hinglish abuse (common in Indian user base)
        "madarchod", "madarchode", "mc", "bhosdike", "bhosdiki",
        "bhenchod", "benchod", "bc", "behenchod",
        "chutiya", "chutiye", "chut",
        "gaandu", "gandu", "gand",
        "randi", "randee", "harami", "haramkhor",
        "lavde", "laude", "lundh", "lund",
        "suar", "suwar", "kutte", "kutta", "kamina", "kamine",
    ]

    /// Substrings that should be flagged even inside compound words.
    private static let substringBlockList: [String] = [
        "nigger", "nigga", "faggot",
    ]
}

// MARK: - Helpers

private extension String {
    /// Replaces sequences of 3+ identical characters with a single instance.
    /// e.g. "fuuuck" → "fuck", "shiiit" → "shit"
    func replacingRepeatedCharacters() -> String {
        guard let regex = try? NSRegularExpression(pattern: "(.)\\1{2,}", options: []) else {
            return self
        }
        return regex.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: "$1"
        )
    }
}
