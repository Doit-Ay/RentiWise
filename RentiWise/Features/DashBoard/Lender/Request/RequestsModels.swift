//
//  RequestsModels.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import Foundation

// MARK: - Rental Status State Machine

/// Canonical rental statuses used throughout the app.
/// Maps to the `status` column in the `requests` table.
public enum RentalStatus: String, CaseIterable, Codable {
    case pending    = "pending"     // Borrower sent request; awaiting lender decision
    case accepted   = "accepted"   // Lender accepted; awaiting payment and pickup verification
    case denied     = "denied"     // Lender denied the request
    case approved   = "approved"   // Pickup OTP verified; rental is active
    case completed  = "completed"  // Item returned and accepted by lender
    case cancelled  = "cancelled"  // Borrower cancelled the request
    case rejected   = "rejected"   // Alias for denied (used in some older flows)
    case returned   = "returned"   // Return submitted, awaiting lender confirmation

    // MARK: - Parsing from DB strings

    /// Parses a raw status string from the database. Case-insensitive, trims whitespace.
    public init(rawDBValue: String) {
        let cleaned = rawDBValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = RentalStatus(rawValue: cleaned) ?? .pending
    }

    // MARK: - State queries

    /// The rental is in a terminal state — no further transitions are possible.
    public var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .denied, .rejected:
            return true
        default:
            return false
        }
    }

    /// The rental is currently active (item is with borrower).
    public var isActive: Bool {
        self == .approved
    }

    /// Borrower can request an extension (only while rental is active).
    public var canExtend: Bool {
        self == .approved
    }

    /// Borrower can submit a return request (only while rental is active).
    public var canReturn: Bool {
        self == .approved
    }

    /// Borrower can cancel the request (only while pending or accepted).
    public var canCancel: Bool {
        switch self {
        case .pending, .accepted:
            return true
        default:
            return false
        }
    }

    /// Borrower can still cancel before pickup is verified.
    var borrowerCanCancelBeforePickup: Bool {
        switch self {
        case .pending, .accepted:
            return true
        default:
            return false
        }
    }

    /// Borrower can use extend/return actions only once the rental is active.
    var borrowerShowsExtendAndReturnActions: Bool {
        switch self {
        case .approved, .returned:
            return true
        default:
            return false
        }
    }

    /// Main borrower CTA used in the booking detail screen.
    var borrowerPrimaryActionTitle: String? {
        if borrowerCanCancelBeforePickup { return "Cancel Request" }
        if borrowerShowsExtendAndReturnActions { return "Return Item" }
        return nil
    }

    var borrowerPrimaryActionIsDestructive: Bool {
        borrowerCanCancelBeforePickup
    }

    /// Lender can accept or deny (only while pending).
    public var canLenderDecide: Bool {
        self == .pending
    }

    /// Lender can verify pickup OTP (only while accepted).
    public var canVerifyPickup: Bool {
        self == .accepted
    }

    // MARK: - Valid transitions

    /// Returns true if transitioning from this status to `newStatus` is valid.
    public func canTransition(to newStatus: RentalStatus) -> Bool {
        switch self {
        case .pending:
            return [.accepted, .denied, .rejected, .cancelled].contains(newStatus)
        case .accepted:
            return [.approved, .denied, .cancelled].contains(newStatus)
        case .approved:
            return [.returned, .completed].contains(newStatus)
        case .returned:
            return [.completed].contains(newStatus)
        case .denied, .rejected, .cancelled, .completed:
            return false // terminal states
        }
    }

    // MARK: - Display

    /// Human-readable display name for the status.
    public var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .accepted:  return "Accepted"
        case .denied:    return "Denied"
        case .approved:  return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .rejected:  return "Rejected"
        case .returned:  return "Return Pending"
        }
    }

    /// Maps to the `RequestStatus` enum used in `BookingApprovalViewController`.
    /// This bridges the old enum-based UI code to the new canonical status.
    var bookingApprovalStatus: BookingApprovalViewController.RequestStatus {
        switch self {
        case .pending:                    return .pending
        case .accepted:                   return .approved   // "accepted" shows as approved with OTP
        case .approved:                   return .approved
        case .denied, .rejected:          return .rejected
        case .cancelled:                  return .cancelled
        case .completed:                  return .completed
        case .returned:                   return .approved    // still active until lender confirms
        }
    }
}

// MARK: - Shared models for lender requests with joined item

public struct RequestWithItem: Codable, Sendable {
    public let id: String
    public let item_id: String
    public let owner_id: String
    public let borrower_id: String
    public let start_date: String   // "yyyy-MM-dd"
    public let end_date: String     // "yyyy-MM-dd"
    public let pickup_time: String?
    public var pickup_code: String?
    public var status: String
    public let created_at: String?
    public let rental_unit: String? // "hour" or "day"
    public let return_time: String?

    public let items: ItemLite? // joined item

    // MARK: - Computed helpers

    /// Parsed `RentalStatus` from the raw status string.
    public var rentalStatus: RentalStatus {
        RentalStatus(rawDBValue: status)
    }
}

public enum RequestSchemaSupport {
    private static var cachedPickupCodeSupport = true

    public static var supportsPickupCode: Bool {
        cachedPickupCodeSupport
    }

    public static func markPickupCodeUnavailable() {
        cachedPickupCodeSupport = false
    }

    public static func isMissingPickupCodeError(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("pickup_code") && (message.contains("schema cache") || message.contains("column"))
    }
}

public struct ItemLite: Codable, Sendable {
    public let id: String
    public let title: String
    public let images: [String]
    public let price_per_day: Double
    public let category: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case images
        case price_per_day
        case category
    }
}

public extension ItemLite {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        price_per_day = try container.decode(Double.self, forKey: .price_per_day)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }
}
