// NotificationService.swift
// RentiWise
//
// Centralized service for creating in-app notifications for both lender and borrower.
// Writes to the `notifications` table in Supabase.

import Foundation
import Supabase

/// Lightweight service that inserts rows into the `notifications` table.
/// Every method is static and fire-and-forget — callers don't need to await results.
enum RemoteNotificationService {

    // MARK: - Public API

    /// Notify the borrower that their request was accepted by the lender.
    static func sendRequestAccepted(requestId: String, borrowerId: String, itemTitle: String) {
        insert(
            userId: borrowerId,
            type: "request_accepted",
            title: "Request Accepted ✅",
            message: "Your rental request for \"\(itemTitle)\" has been accepted! You can now proceed to payment.",
            requestId: requestId
        )
    }

    /// Notify the borrower that their request was rejected by the lender.
    static func sendRequestRejected(requestId: String, borrowerId: String, itemTitle: String) {
        insert(
            userId: borrowerId,
            type: "request_rejected",
            title: "Request Rejected",
            message: "Your rental request for \"\(itemTitle)\" has been declined by the owner.",
            requestId: requestId
        )
    }

    /// Notify the lender that the borrower has completed payment.
    static func sendPaymentReceived(requestId: String, ownerId: String, itemTitle: String) {
        insert(
            userId: ownerId,
            type: "payment_received",
            title: "Payment Received 💰",
            message: "The borrower has completed payment for \"\(itemTitle)\". You can now confirm the pickup using the OTP code.",
            requestId: requestId
        )
    }

    /// Notify both parties that pickup has been confirmed via OTP.
    static func sendPickupConfirmed(requestId: String, borrowerId: String, ownerId: String, itemTitle: String) {
        // Notify borrower
        insert(
            userId: borrowerId,
            type: "pickup_confirmed",
            title: "Pickup Confirmed ✅",
            message: "The pickup for \"\(itemTitle)\" has been confirmed by the owner. Your rental is now active!",
            requestId: requestId
        )
        // Notify lender
        insert(
            userId: ownerId,
            type: "pickup_confirmed",
            title: "Pickup Confirmed ✅",
            message: "You've confirmed the pickup for \"\(itemTitle)\". The rental is now active.",
            requestId: requestId
        )
    }

    /// Notify the lender that a new rental request was received.
    static func sendNewRequest(requestId: String, ownerId: String, itemTitle: String) {
        insert(
            userId: ownerId,
            type: "new_request",
            title: "New Rental Request 📩",
            message: "Someone wants to rent your \"\(itemTitle)\". Review and respond to the request.",
            requestId: requestId
        )
    }

    // MARK: - Private

    private struct NotificationInsert: Encodable {
        let user_id: String
        let type: String
        let title: String
        let message: String
        let request_id: String?
        let is_read: Bool
    }

    private static func insert(userId: String, type: String, title: String, message: String, requestId: String?) {
        Task {
            do {
                let payload = NotificationInsert(
                    user_id: userId,
                    type: type,
                    title: title,
                    message: message,
                    request_id: requestId,
                    is_read: false
                )
                _ = try await SupabaseManager.shared.client
                    .from("notifications")
                    .insert(payload)
                    .execute()
                debugLog("[NotificationService] Sent \(type) to user \(userId)")
            } catch {
                // Fire-and-forget: log but don't crash
                debugLog("[NotificationService] Failed to send \(type): \(error.localizedDescription)")
            }
        }
    }
}
