//
//  RentiWiseTests.swift
//  RentiWiseTests
//
//  Created by admin99 on 18/10/25.
//

import Foundation
import Testing
@testable import RentiWise

struct RentiWiseTests {

    @Test func listingModerationAllowsSafeContent() throws {
        let draft = AddItemDraft(
            images: [],
            title: "Study Lamp",
            description: "Clean desk lamp for hostel use",
            category: "Electronics",
            condition: "Good",
            pricePerDay: 20,
            depositAmount: 100,
            declaredValue: 800,
            isActive: true
        )

        try SafetyContentPolicy.validateListing(draft)
        #expect(SafetyContentPolicy.containsRestrictedListingContent(
            title: draft.title,
            description: draft.description,
            category: draft.category,
            condition: draft.condition
        ) == false)
    }

    @Test func listingModerationBlocksRestrictedTerms() {
        #expect(SafetyContentPolicy.containsRestrictedListingContent(
            title: "Counterfeit headphones",
            description: "Looks like a branded product",
            category: "Accessories",
            condition: "Used"
        ))
    }

    @Test func chatRateLimiterBlocksSpamBursts() async throws {
        let limiter = ChatMessageRateLimiter()
        let start = Date(timeIntervalSince1970: 0)

        for index in 0..<20 {
            try await limiter.registerSend(for: "conversation-1", now: start.addingTimeInterval(Double(index)))
        }

        var rateLimitError: SafetyContentViolation?
        do {
            try await limiter.registerSend(for: "conversation-1", now: start.addingTimeInterval(20))
        } catch let error as SafetyContentViolation {
            rateLimitError = error
        } catch {
            Issue.record("Expected a SafetyContentViolation but received \(error)")
        }

        #expect(rateLimitError == .messageRateLimited(secondsRemaining: 40))
    }

}
