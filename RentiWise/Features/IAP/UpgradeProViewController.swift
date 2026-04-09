//
//  UpgradeProViewController.swift
//  RentiWise
//
//  Shown when a free user tries to publish more than 3 listings.
//  Displays Lender Pro benefits and subscription CTA.
//  Uses Razorpay for payment processing.
//

import UIKit
import Supabase

final class UpgradeProViewController: UIViewController {

    private enum CheckoutRecoveryTrigger {
        case returnedFromPayment
        case timeout
    }

    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    private let subscribeButtonIdleTitle = "Subscribe Now"
    private let subscribeButtonProcessingTitle = "Processing..."
    private let checkoutTimeoutNanoseconds: UInt64 = 45_000_000_000
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var subscribeButton: UIButton!
    private var checkoutRecoveryTask: Task<Void, Never>?
    private var isCheckoutInProgress = false
    private var didLeaveAppForPayment = false
    private var didPresentSuccessState = false

    var onSubscribed: (() -> Void)?

    deinit {
        checkoutRecoveryTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lender Pro"
        view.backgroundColor = .systemBackground
        setupUI()
        registerPaymentLifecycleObservers()
    }

    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])

        // Icon
        let crownIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        crownIcon.tintColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.translatesAutoresizingMaskIntoConstraints = false
        crownIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        contentStack.addArrangedSubview(crownIcon)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Unlock Lender Pro"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        contentStack.addArrangedSubview(titleLabel)

        // Subtitle
        let subtitle = UILabel()
        subtitle.text = "You've reached the free limit of 3 listings."
        subtitle.font = .systemFont(ofSize: 16)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        contentStack.addArrangedSubview(subtitle)

        // Benefits card
        let benefitsCard = UIView()
        benefitsCard.backgroundColor = .secondarySystemBackground
        benefitsCard.layer.cornerRadius = 16
        benefitsCard.translatesAutoresizingMaskIntoConstraints = false

        let benefitsStack = UIStackView()
        benefitsStack.axis = .vertical
        benefitsStack.spacing = 16
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false

        let benefits = [
            ("infinity", "Unlimited Listings", "List as many items as you want"),
            ("chart.bar.fill", "Analytics Dashboard", "See views, clicks, and earnings"),
            ("star.fill", "Priority Support", "Get help faster from our team"),
            ("bolt.fill", "Early Access", "Try new features before everyone"),
        ]

        for (icon, title, desc) in benefits {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .top

            let iconView = UIImageView(image: UIImage(systemName: icon))
            iconView.tintColor = brandTeal
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2

            let titleLbl = UILabel()
            titleLbl.text = title
            titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)

            let descLbl = UILabel()
            descLbl.text = desc
            descLbl.font = .systemFont(ofSize: 14)
            descLbl.textColor = .secondaryLabel
            descLbl.numberOfLines = 0

            textStack.addArrangedSubview(titleLbl)
            textStack.addArrangedSubview(descLbl)

            row.addArrangedSubview(iconView)
            row.addArrangedSubview(textStack)
            benefitsStack.addArrangedSubview(row)
        }

        benefitsCard.addSubview(benefitsStack)
        NSLayoutConstraint.activate([
            benefitsStack.topAnchor.constraint(equalTo: benefitsCard.topAnchor, constant: 20),
            benefitsStack.leadingAnchor.constraint(equalTo: benefitsCard.leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: benefitsCard.trailingAnchor, constant: -16),
            benefitsStack.bottomAnchor.constraint(equalTo: benefitsCard.bottomAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(benefitsCard)

        // Price
        let priceLabel = UILabel()
        let price = RazorpayPaymentService.lenderProMonthlyPrice
        priceLabel.text = "₹\(Int(price))/month"
        priceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        priceLabel.textColor = brandTeal
        priceLabel.textAlignment = .center
        contentStack.addArrangedSubview(priceLabel)

        // Subscribe button
        subscribeButton = UIButton(type: .system)
        subscribeButton.setTitle(subscribeButtonIdleTitle, for: .normal)
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        subscribeButton.backgroundColor = brandTeal
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 14
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        subscribeButton.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(subscribeButton)

        // Maybe Later
        let laterButton = UIButton(type: .system)
        laterButton.setTitle("Maybe Later", for: .normal)
        laterButton.titleLabel?.font = .systemFont(ofSize: 16)
        laterButton.setTitleColor(.secondaryLabel, for: .normal)
        laterButton.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(laterButton)

        // Payment info
        let infoLabel = UILabel()
        infoLabel.text = "Secure payment powered by Razorpay. Supports UPI, Cards, Net Banking & Wallets."
        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .tertiaryLabel
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        contentStack.addArrangedSubview(infoLabel)

        // Legal links (required by Guideline 3.1.2)
        let legalStack = UIStackView()
        legalStack.axis = .horizontal
        legalStack.spacing = 16
        legalStack.alignment = .center
        legalStack.distribution = .equalCentering

        let tosButton = UIButton(type: .system)
        tosButton.setTitle("Terms of Service", for: .normal)
        tosButton.titleLabel?.font = .systemFont(ofSize: 12)
        tosButton.setTitleColor(.secondaryLabel, for: .normal)
        tosButton.addTarget(self, action: #selector(showTerms), for: .touchUpInside)

        let separator = UILabel()
        separator.text = "•"
        separator.font = .systemFont(ofSize: 12)
        separator.textColor = .tertiaryLabel

        let ppButton = UIButton(type: .system)
        ppButton.setTitle("Privacy Policy", for: .normal)
        ppButton.titleLabel?.font = .systemFont(ofSize: 12)
        ppButton.setTitleColor(.secondaryLabel, for: .normal)
        ppButton.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)

        legalStack.addArrangedSubview(tosButton)
        legalStack.addArrangedSubview(separator)
        legalStack.addArrangedSubview(ppButton)
        contentStack.addArrangedSubview(legalStack)
    }

    @objc private func showTerms() {
        let vc = LegalDocumentViewController(document: .termsOfService)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func showPrivacy() {
        let vc = LegalDocumentViewController(document: .privacyPolicy)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func registerPaymentLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Actions
    @objc private func subscribeTapped() {
        guard !isCheckoutInProgress else { return }
        beginCheckoutProcessing()

        Task {
            // Fetch user details for Razorpay prefill
            var userEmail = ""
            var userPhone = ""
            var userName = ""
            var userId = ""

            if let uid = await SupabaseManager.shared.currentUserId() {
                userId = uid
                struct UserDTO: Decodable { let full_name: String?; let email: String?; let phone: String? }
                do {
                    let resp = try await SupabaseManager.shared.client
                        .from("user_profiles")
                        .select("full_name, email, phone")
                        .eq("id", value: uid)
                        .single()
                        .execute()
                    if let dto = try? JSONDecoder().decode(UserDTO.self, from: resp.data) {
                        userName = dto.full_name ?? ""
                        userEmail = dto.email ?? ""
                        userPhone = dto.phone ?? ""
                    }
                } catch { }
            }

            await MainActor.run {
                RazorpayPaymentService.shared.openCheckout(
                    amount: RazorpayPaymentService.lenderProMonthlyPrice,
                    productName: "Lender Pro — Monthly",
                    productId: IAPManager.lenderProProductId,
                    userEmail: userEmail,
                    userPhone: userPhone,
                    userName: userName,
                    presentingVC: self,
                    success: { [weak self] paymentId in
                        guard let self else { return }
                        Task { await self.handleSuccessfulCheckout(userId: userId, paymentId: paymentId) }
                    },
                    failure: { [weak self] code, description in
                        guard let self else { return }
                        Task { [weak self] in
                            guard let self else { return }
                            await MainActor.run {
                                self.resetCheckoutProcessing()
                                // Code 2 = user cancelled, don't show error
                                if code != 2 {
                                    self.showAlert(title: "Payment Failed", message: description)
                                }
                            }
                        }
                    }
                )
            }
        }
    }

    @objc private func handleAppWillResignActive() {
        guard isCheckoutInProgress else { return }
        didLeaveAppForPayment = true
    }

    @objc private func handleAppDidBecomeActive() {
        guard isCheckoutInProgress, didLeaveAppForPayment else { return }
        didLeaveAppForPayment = false
        scheduleCheckoutRecovery(after: 1_200_000_000, trigger: .returnedFromPayment)
    }

    private func handleSuccessfulCheckout(userId: String, paymentId: String) async {
        debugLog("[LenderPro] Razorpay payment succeeded: \(paymentId)")

        await MainActor.run {
            checkoutRecoveryTask?.cancel()
        }

        let entitlementSaved = await recordProSubscription(userId: userId, paymentId: paymentId)
        let entitlementConfirmed: Bool
        if entitlementSaved {
            entitlementConfirmed = true
        } else {
            entitlementConfirmed = await IAPManager.shared.isProUser()
        }

        await MainActor.run {
            if entitlementConfirmed {
                NotificationCenter.default.post(name: .iapEntitlementsDidChange, object: nil)
            }
            presentSuccessState(entitlementConfirmed: entitlementConfirmed)
        }
    }

    @MainActor
    private func beginCheckoutProcessing() {
        didPresentSuccessState = false
        isCheckoutInProgress = true
        didLeaveAppForPayment = false
        subscribeButton.isEnabled = false
        subscribeButton.setTitle(subscribeButtonProcessingTitle, for: .normal)
        scheduleCheckoutRecovery(after: checkoutTimeoutNanoseconds, trigger: .timeout)
    }

    @MainActor
    private func resetCheckoutProcessing() {
        checkoutRecoveryTask?.cancel()
        checkoutRecoveryTask = nil
        isCheckoutInProgress = false
        didLeaveAppForPayment = false
        subscribeButton.isEnabled = true
        subscribeButton.setTitle(subscribeButtonIdleTitle, for: .normal)
    }

    @MainActor
    private func presentSuccessState(entitlementConfirmed: Bool) {
        guard !didPresentSuccessState else { return }
        didPresentSuccessState = true
        resetCheckoutProcessing()

        let message = entitlementConfirmed
            ? "You now have unlimited listings and a Lender Pro badge on your profile."
            : "Your payment went through. We're still syncing the Pro badge to your profile, so pull to refresh Profile in a few seconds if it doesn't appear immediately."

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.showAlert(title: "Welcome to Pro! 🎉", message: message) { [weak self] in
                self?.onSubscribed?()
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }

    @MainActor
    private func scheduleCheckoutRecovery(after delay: UInt64, trigger: CheckoutRecoveryTrigger) {
        checkoutRecoveryTask?.cancel()
        checkoutRecoveryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.recoverPendingCheckout(trigger: trigger)
        }
    }

    private func recoverPendingCheckout(trigger: CheckoutRecoveryTrigger) async {
        let shouldContinue = await MainActor.run {
            isCheckoutInProgress && !didPresentSuccessState
        }
        guard shouldContinue else { return }

        let entitlementConfirmed = await IAPManager.shared.isProUser()

        await MainActor.run {
            guard isCheckoutInProgress, !didPresentSuccessState else { return }

            if entitlementConfirmed {
                NotificationCenter.default.post(name: .iapEntitlementsDidChange, object: nil)
                presentSuccessState(entitlementConfirmed: true)
                return
            }

            resetCheckoutProcessing()
            if trigger == .timeout {
                showAlert(
                    title: "Still Processing",
                    message: "We couldn't confirm Lender Pro yet. If money was deducted, open Profile and refresh in a few seconds, or try again."
                )
            }
        }
    }

    /// Records the Lender Pro entitlement in user_entitlements after successful payment
    private func recordProSubscription(userId: String, paymentId: String) async -> Bool {
        guard !userId.isEmpty else { return false }
        do {
            let now = Date()
            let expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
            let isoFormatter = ISO8601DateFormatter()

            struct EntitlementRow: Encodable {
                let user_id: String
                let product_id: String
                let transaction_id: String
                let is_active: Bool
                let purchased_at: String
                let expires_at: String
            }

            let row = EntitlementRow(
                user_id: userId,
                product_id: IAPManager.lenderProProductId,
                transaction_id: paymentId,
                is_active: true,
                purchased_at: isoFormatter.string(from: now),
                expires_at: isoFormatter.string(from: expiresAt)
            )

            try await SupabaseManager.shared.client
                .from("user_entitlements")
                .insert(row)
                .execute()

            debugLog("[LenderPro] Recorded Pro entitlement for user \(userId)")
            return true
        } catch {
            debugLog("[LenderPro] Failed to record entitlement: \(error)")
            return false
        }
    }

    @objc private func laterTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        if let presented = presentedViewController, !(presented is UIAlertController) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.showAlert(title: title, message: message, completion: completion)
            }
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true)
    }
}
