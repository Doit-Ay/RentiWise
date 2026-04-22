// NotificationService.swift
// RentiWise
//
// Centralized service for creating in-app notifications for both lender and borrower.
// Uses the `create_notification` RPC in Supabase.

import Foundation
import Supabase

/// Lightweight service that creates rows in `notifications` via a secure RPC.
/// Every method is static and fire-and-forget — callers don't need to await results.
enum RemoteNotificationService {

    // MARK: - Public API

    /// Notify the borrower that their request was accepted by the lender.
    static func sendRequestAccepted(requestId: String, borrowerId: String, itemTitle: String) {
        insert(
            userId: borrowerId,
            type: "request_accepted",
            title: "Request Accepted",
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
            title: "Payment Received",
            message: "The borrower marked payment as sent for \"\(itemTitle)\". Confirm receipt to unlock pickup OTP verification.",
            requestId: requestId
        )
    }

    /// Notify the borrower that the lender confirmed the UPI payment and OTP is now available.
    static func sendPaymentConfirmed(requestId: String, borrowerId: String, itemTitle: String) {
        insert(
            userId: borrowerId,
            type: "payment_confirmed",
            title: "Payment Confirmed",
            message: "The lender confirmed payment for \"\(itemTitle)\". Your pickup OTP is now ready.",
            requestId: requestId
        )
    }

    /// Notify both parties that pickup has been confirmed via OTP.
    static func sendPickupConfirmed(requestId: String, borrowerId: String, ownerId: String, itemTitle: String) {
        // Notify borrower
        insert(
            userId: borrowerId,
            type: "pickup_confirmed",
            title: "Pickup Confirmed",
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
            title: "New Rental Request",
            message: "Someone wants to rent your \"\(itemTitle)\". Review and respond to the request.",
            requestId: requestId
        )
    }

    /// Notify a nearby user that a new listing was posted close to them.
    static func sendNearbyItemPosted(itemId: String, userId: String, itemTitle: String, distanceText: String) {
        insert(
            userId: userId,
            type: "nearby_item_posted",
            title: "New Item Nearby",
            message: "\"\(itemTitle)\" was just listed near you (\(distanceText)).",
            itemId: itemId
        )
    }

    // MARK: - Private

    private struct NotificationRPCPayload: Encodable {
        let target_user_id: String
        let notification_type: String
        let notification_title: String
        let notification_message: String
        let request_ref_id: String?
        let item_ref_id: String?
    }

    private static func insert(
        userId: String,
        type: String,
        title: String,
        message: String,
        requestId: String? = nil,
        itemId: String? = nil
    ) {
        Task {
            do {
                let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedRequestId = requestId?.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedItemId = itemId?.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedUserId.isEmpty else {
                    debugLog("[NotificationService] Skipped \(type): missing target user id")
                    return
                }

                if type == "nearby_item_posted" {
                    guard let trimmedItemId, !trimmedItemId.isEmpty else {
                        debugLog("[NotificationService] Skipped nearby_item_posted: missing item id")
                        return
                    }
                } else {
                    guard let trimmedRequestId, !trimmedRequestId.isEmpty else {
                        debugLog("[NotificationService] Skipped \(type): missing request id")
                        return
                    }
                }

                let payload = NotificationRPCPayload(
                    target_user_id: trimmedUserId,
                    notification_type: type,
                    notification_title: title,
                    notification_message: message,
                    request_ref_id: trimmedRequestId?.isEmpty == false ? trimmedRequestId : nil,
                    item_ref_id: trimmedItemId?.isEmpty == false ? trimmedItemId : nil
                )

                _ = try await SupabaseManager.shared.client
                    .rpc("create_notification", params: payload)
                    .execute()

                if SupabaseManager.shared.currentUserIdSync()?.lowercased() == trimmedUserId.lowercased() {
                    NotificationCenter.default.post(name: .notificationsDidUpdate, object: nil)
                }
                debugLog("[NotificationService] Sent \(type) to user \(trimmedUserId)")
            } catch {
                // Fire-and-forget: log but don't crash
                debugLog("[NotificationService] Failed to send \(type): \(error.localizedDescription)")
            }
        }
    }
}
