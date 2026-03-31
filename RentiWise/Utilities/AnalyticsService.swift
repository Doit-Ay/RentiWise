//
//  AnalyticsService.swift
//  RentiWise
//
//  Lightweight analytics event logger stub.
//  Currently logs events to the debug console. Ready to be swapped
//  out for a real analytics SDK (Firebase Analytics, Mixpanel, etc.)
//  without changing any call-sites.
//

import Foundation

/// Lightweight analytics event logging service.
/// All events are currently logged to the debug console only.
/// Swap the `track(_:properties:)` implementation with a real SDK
/// when needed — no call-site changes required.
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    /// Whether analytics logging is enabled. Disable in unit tests.
    var isEnabled: Bool = true

    // MARK: - Core Event Tracking

    /// Logs a named event with optional properties.
    /// - Parameters:
    ///   - event: Event name (e.g., "rental_request_sent", "pickup_verified").
    ///   - properties: Key-value pairs for additional context (e.g., ["item_id": "abc123"]).
    func track(_ event: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }

        var message = "[Analytics] \(event)"
        if let props = properties, !props.isEmpty {
            let propsString = props.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " { \(propsString) }"
        }
        debugLog(message)
    }

    // MARK: - Predefined Events (Type-Safe)

    /// Tracks when a user views a product detail page.
    func trackProductViewed(itemId: String) {
        track("product_viewed", properties: ["item_id": itemId])
    }

    /// Tracks when a rental request is sent by a borrower.
    func trackRentalRequestSent(itemId: String, days: Int) {
        track("rental_request_sent", properties: [
            "item_id": itemId,
            "rental_days": days
        ])
    }

    /// Tracks when a lender accepts or denies a request.
    func trackRequestDecision(requestId: String, decision: String) {
        track("request_decision", properties: [
            "request_id": requestId,
            "decision": decision
        ])
    }

    /// Tracks when pickup OTP verification completes.
    func trackPickupVerified(requestId: String) {
        track("pickup_verified", properties: ["request_id": requestId])
    }

    /// Tracks when a return or extension request is submitted.
    func trackSubRequestSubmitted(requestId: String, type: String) {
        track("sub_request_submitted", properties: [
            "request_id": requestId,
            "type": type
        ])
    }

    /// Tracks when a rental is completed or cancelled.
    func trackRentalEnded(requestId: String, status: String) {
        track("rental_ended", properties: [
            "request_id": requestId,
            "status": status
        ])
    }

    /// Tracks when a user signs in or out.
    func trackAuth(event: String, method: String? = nil) {
        var props: [String: Any] = [:]
        if let method { props["method"] = method }
        track("auth_\(event)", properties: props.isEmpty ? nil : props)
    }

    /// Tracks screen views for understanding navigation patterns.
    func trackScreenView(_ screenName: String) {
        track("screen_view", properties: ["screen": screenName])
    }
}
