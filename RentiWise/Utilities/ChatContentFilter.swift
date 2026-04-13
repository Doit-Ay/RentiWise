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

        // Build word set (split on non-alpha)
        let words = normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }

        for word in words {
            if slurs.contains(word) {
                return "Your message contains language that violates our community guidelines."
            }
        }

        // Substring scan for terms that may appear within words
        for term in substringBlockList {
            if normalized.contains(term) {
                return "Your message contains language that violates our community guidelines."
            }
        }

        return nil // clean
    }

    // MARK: - Word Lists

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
