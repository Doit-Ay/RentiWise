//
//  RazorpayPaymentService.swift
//  RentiWise
//
//  Handles Razorpay payment checkout for in-app purchases (Lender Pro subscription).
//  Uses test keys for development; switch to live keys for production.
//  NOTE: This is ONLY for in-app purchases (subscriptions, boosts, badges).
//        Rental payments between borrower and lender use direct UPI.
//

import UIKit
import Razorpay

/// Centralized Razorpay payment service for RentiWise in-app purchases.
/// Used for Lender Pro subscription, Listing Boosts, and Verified Badge purchases.
final class RazorpayPaymentService: NSObject, RazorpayPaymentCompletionProtocol {

    static let shared = RazorpayPaymentService()

    // MARK: - Configuration (Test Keys)
    private static let keyId = "rzp_test_SZrghcPJPA8Iss"

    // MARK: - Product Prices (INR)
    static let lenderProMonthlyPrice: Double = 99.0
    static let listingBoostPrice: Double = 29.0
    static let verifiedBadgePrice: Double = 49.0

    private var razorpay: RazorpayCheckout?
    private var onSuccess: ((String) -> Void)?
    private var onFailure: ((Int32, String) -> Void)?

    private override init() {
        super.init()
        razorpay = RazorpayCheckout.initWithKey(Self.keyId, andDelegate: self)
    }

    // MARK: - Public API

    /// Opens Razorpay checkout for an in-app purchase (Lender Pro, Boost, Badge).
    func openCheckout(
        amount: Double,
        productName: String,
        productId: String,
        userEmail: String = "",
        userPhone: String = "",
        userName: String = "",
        presentingVC: UIViewController,
        success: @escaping (String) -> Void,
        failure: @escaping (Int32, String) -> Void
    ) {
        self.onSuccess = success
        self.onFailure = failure

        let amountInPaise = Int(amount * 100)

        let options: [String: Any] = [
            "amount": amountInPaise,
            "currency": "INR",
            "name": "RentiWise",
            "description": productName,
            "prefill": [
                "email": userEmail,
                "contact": userPhone,
                "name": userName
            ],
            "notes": [
                "product_id": productId,
                "product_name": productName
            ],
            "theme": [
                "color": "#5DA9B6"
            ]
        ]

        razorpay?.open(options, displayController: presentingVC)
    }

    // MARK: - RazorpayPaymentCompletionProtocol (required methods)

    func onPaymentSuccess(_ payment_id: String) {
        debugLog("[Razorpay] Payment succeeded: \(payment_id)")
        let callback = onSuccess
        onSuccess = nil
        onFailure = nil
        callback?(payment_id)
    }

    func onPaymentError(_ code: Int32, description str: String) {
        debugLog("[Razorpay] Payment failed: \(code) — \(str)")
        let callback = onFailure
        onSuccess = nil
        onFailure = nil
        callback?(code, str)
    }

    // MARK: - Optional andData variants (newer SDK versions)

    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable : Any]) {
        onPaymentSuccess(payment_id)
    }

    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable : Any]) {
        onPaymentError(code, description: str)
    }
}
