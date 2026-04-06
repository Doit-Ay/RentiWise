//
//  NotificationService.swift
//  RentiWise
//
//  Local push notification scheduler for rental lifecycle events.
//

import Foundation
import UserNotifications

extension Notification.Name {
    static let notificationsDidUpdate = Notification.Name("RentiWiseNotificationsDidUpdate")
}

/// Lightweight local notification manager for rental lifecycle events.
/// Coordinates permission requests and schedules reminders for approaching due dates,
/// status changes, and return/extension updates.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private override init() {
        super.init()
        center.delegate = self
    }

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Requests notification permission. Safe to call multiple times — subsequent calls are no-ops if already authorized.
    func requestPermissionIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        debugLog("[Notifications] Permission error: \(error.localizedDescription)")
                    } else {
                        debugLog("[Notifications] Permission granted: \(granted)")
                    }
                }
            case .denied:
                debugLog("[Notifications] Permission previously denied — skipping request")
            default:
                break // Already authorized or provisional
            }
        }
    }

    /// Ensures notification authorization before scheduling. Requests permission
    /// lazily on first use so no system dialog appears at launch (TC-PR03).
    private func ensureAuthorizedThenSchedule(_ schedule: @escaping () -> Void) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                schedule()
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        debugLog("[Notifications] Permission error: \(error.localizedDescription)")
                    }
                    if granted { schedule() }
                }
            default:
                debugLog("[Notifications] Permission denied — notification not scheduled")
            }
        }
    }

    // MARK: - Rental Due Date Reminder

    /// Schedules a reminder 24 hours before the rental end date.
    /// - Parameters:
    ///   - requestId: Unique ID of the rental request (used as notification identifier for dedup).
    ///   - itemTitle: Name of the item for the notification body.
    ///   - endDateString: "yyyy-MM-dd" end date from the `requests` table.
    func scheduleRentalDueReminder(requestId: String, itemTitle: String, endDateString: String) {
        ensureAuthorizedThenSchedule { [weak self] in
            guard let self else { return }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"

            guard let endDate = formatter.date(from: endDateString) else { return }

            // Reminder: 24 h before end date, at 9 AM local
            var calendar = Calendar.current
            calendar.timeZone = .current
            guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }

            // Don't schedule if the reminder would be in the past
            guard reminderDate > Date() else { return }

            var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = 9
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Rental Due Tomorrow"
            content.body = "\"\(itemTitle)\" is due for return tomorrow. Extend or return it to avoid late fees."
            content.sound = .default
            content.categoryIdentifier = "RENTAL_DUE"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = "rental_due_\(requestId)"

            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error = error {
                    debugLog("[Notifications] Failed to schedule due reminder: \(error)")
                }
            }
        }
    }

    // MARK: - Status Change Notification

    /// Shows an immediate local notification when a rental status changes.
    /// - Parameters:
    ///   - requestId: Rental request ID.
    ///   - itemTitle: Item name.
    ///   - newStatus: The new status (e.g., "accepted", "denied", "completed").
    ///   - role: "borrower" or "lender" — used to customize the message.
    func notifyStatusChange(requestId: String, itemTitle: String, newStatus: RentalStatus, role: String) {
        let title: String
        let body: String

        switch newStatus {
        case .accepted:
            title = "Request Accepted"
            body = role == "borrower"
                ? "Your request for \"\(itemTitle)\" was accepted. Pay the lender via UPI to continue."
                : "You accepted the request for \"\(itemTitle)\"."
        case .denied, .rejected:
            title = "Request Denied"
            body = role == "borrower"
                ? "Your request for \"\(itemTitle)\" was denied."
                : "You denied the request for \"\(itemTitle)\"."
        case .approved:
            title = "Rental Active"
            body = "Pickup verified! The rental for \"\(itemTitle)\" is now active."
        case .completed:
            title = "Rental Completed"
            body = role == "borrower"
                ? "Your rental of \"\(itemTitle)\" is complete. Leave a review!"
                : "The rental of \"\(itemTitle)\" is complete."
        case .cancelled:
            title = "Request Cancelled"
            body = "The request for \"\(itemTitle)\" has been cancelled."
        default:
            return
        }

        notifyImmediately(
            identifier: "status_\(requestId)_\(newStatus.rawValue)",
            title: title,
            body: body
        )
    }

    // MARK: - Return / Extension Request Notifications

    /// Notifies the lender that a return or extension request was submitted.
    func notifyNewSubRequest(requestId: String, itemTitle: String, type: String) {
        let isReturn = type == "return"
        notifyImmediately(
            identifier: "sub_\(type)_\(requestId)",
            title: isReturn ? "Return Request" : "Extension Request",
            body: isReturn
                ? "A borrower wants to return \"\(itemTitle)\". Review the request."
                : "A borrower wants to extend the rental of \"\(itemTitle)\". Review the request."
        )
    }

    func notifyImmediately(
        identifier: String,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        ensureAuthorizedThenSchedule { [weak self] in
            guard let self else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = userInfo

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            self.center.add(request) { error in
                if let error = error {
                    debugLog("[Notifications] Failed to schedule immediate notification: \(error)")
                }
            }
        }
    }

    // MARK: - Cleanup

    /// Removes all pending notifications for a specific request (e.g., after completion/cancellation).
    func cancelNotifications(forRequestId requestId: String) {
        let prefixes = ["rental_due_\(requestId)", "status_\(requestId)"]
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .map(\.identifier)
                .filter { id in prefixes.contains(where: { id.hasPrefix($0) }) }
            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}
