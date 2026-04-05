//
//  BoostItemViewController.swift
//  RentiWise
//
//  Lets a lender boost their item to the top of its category for 7 days.
//  Accessed from the "…" menu on own-item mode in ProductViewController.
//  Uses Razorpay for payment processing.
//

import UIKit
import Supabase

final class BoostItemViewController: UIViewController {

    private enum CheckoutRecoveryTrigger {
        case returnedFromPayment
        case timeout
    }

    var itemId: String = ""
    var itemTitle: String = ""
    var categoryName: String = ""

    var onBoosted: (() -> Void)?

    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    private let boostButtonIdleTitle = "⚡ Boost Now"
    private let boostButtonProcessingTitle = "Processing..."
    private let checkoutTimeoutNanoseconds: UInt64 = 45_000_000_000
    private var boostButton: UIButton!
    private var checkoutRecoveryTask: Task<Void, Never>?
    private var isCheckoutInProgress = false
    private var didLeaveAppForPayment = false
    private var didPresentSuccessState = false

    deinit {
        checkoutRecoveryTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Boost Listing"
        view.backgroundColor = .systemBackground
        setupUI()
        registerPaymentLifecycleObservers()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])

        // Bolt icon
        let boltIcon = UIImageView(image: UIImage(systemName: "bolt.fill"))
        boltIcon.tintColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        boltIcon.contentMode = .scaleAspectFit
        boltIcon.translatesAutoresizingMaskIntoConstraints = false
        boltIcon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(boltIcon)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Boost \"\(itemTitle)\""
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // Description
        let descLabel = UILabel()
        let cat = categoryName.isEmpty ? "its category" : categoryName
        descLabel.text = "Your item will appear at the top of \(cat) for 7 days. More visibility means faster rentals!"
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        stack.addArrangedSubview(descLabel)

        // Benefits
        let benefitsCard = UIView()
        benefitsCard.backgroundColor = .secondarySystemBackground
        benefitsCard.layer.cornerRadius = 16

        let benefitsStack = UIStackView()
        benefitsStack.axis = .vertical
        benefitsStack.spacing = 12
        benefitsStack.translatesAutoresizingMaskIntoConstraints = false

        let perks = [
            ("arrow.up.circle.fill", "Appears first in search results"),
            ("eye.fill", "Up to 5x more views"),
            ("bolt.circle.fill", "⚡ Boosted badge on your listing"),
        ]
        for (icon, text) in perks {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            let iv = UIImageView(image: UIImage(systemName: icon))
            iv.tintColor = brandTeal
            iv.widthAnchor.constraint(equalToConstant: 22).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 22).isActive = true
            iv.contentMode = .scaleAspectFit
            let lbl = UILabel()
            lbl.text = text
            lbl.font = .systemFont(ofSize: 15)
            row.addArrangedSubview(iv)
            row.addArrangedSubview(lbl)
            benefitsStack.addArrangedSubview(row)
        }

        benefitsCard.addSubview(benefitsStack)
        NSLayoutConstraint.activate([
            benefitsStack.topAnchor.constraint(equalTo: benefitsCard.topAnchor, constant: 16),
            benefitsStack.leadingAnchor.constraint(equalTo: benefitsCard.leadingAnchor, constant: 16),
            benefitsStack.trailingAnchor.constraint(equalTo: benefitsCard.trailingAnchor, constant: -16),
            benefitsStack.bottomAnchor.constraint(equalTo: benefitsCard.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(benefitsCard)

        // Price
        let priceLabel = UILabel()
        let price = RazorpayPaymentService.listingBoostPrice
        priceLabel.text = "₹\(Int(price))"
        priceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = brandTeal
        priceLabel.textAlignment = .center
        stack.addArrangedSubview(priceLabel)

        // Boost button
        boostButton = UIButton(type: .system)
        boostButton.setTitle(boostButtonIdleTitle, for: .normal)
        boostButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        boostButton.backgroundColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
        boostButton.setTitleColor(.white, for: .normal)
        boostButton.layer.cornerRadius = 14
        boostButton.translatesAutoresizingMaskIntoConstraints = false
        boostButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        boostButton.addTarget(self, action: #selector(boostTapped), for: .touchUpInside)
        stack.addArrangedSubview(boostButton)

        // Payment info
        let infoLabel = UILabel()
        infoLabel.text = "Secure payment powered by Razorpay"
        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .tertiaryLabel
        infoLabel.textAlignment = .center
        stack.addArrangedSubview(infoLabel)
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

    @objc private func boostTapped() {
        guard !isCheckoutInProgress else { return }
        beginCheckoutProcessing()

        Task {
            // Fetch user details for Razorpay prefill
            var userEmail = ""
            var userPhone = ""
            var userName = ""

            if let uid = await SupabaseManager.shared.currentUserId() {
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
                    amount: RazorpayPaymentService.listingBoostPrice,
                    productName: "Listing Boost — 7 Days",
                    productId: IAPManager.boostProductId,
                    userEmail: userEmail,
                    userPhone: userPhone,
                    userName: userName,
                    presentingVC: self,
                    success: { [weak self] _ in
                        guard let self else { return }
                        Task { await self.handleSuccessfulCheckout() }
                    },
                    failure: { [weak self] code, description in
                        guard let self else { return }
                        Task { [weak self] in
                            guard let self else { return }
                            await MainActor.run {
                                self.resetCheckoutProcessing()
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

    private func handleSuccessfulCheckout() async {
        let boostSaved = await applyBoostToItem()
        let boostConfirmed: Bool
        if boostSaved {
            boostConfirmed = true
        } else {
            boostConfirmed = await IAPManager.shared.hasBoostedItem(itemId: itemId)
        }

        await MainActor.run {
            if boostConfirmed {
                NotificationCenter.default.post(name: Notification.Name("itemsShouldRefresh"), object: nil)
            }
            presentSuccessState(boostConfirmed: boostConfirmed)
        }
    }

    @MainActor
    private func beginCheckoutProcessing() {
        didPresentSuccessState = false
        isCheckoutInProgress = true
        didLeaveAppForPayment = false
        boostButton.isEnabled = false
        boostButton.setTitle(boostButtonProcessingTitle, for: .normal)
        scheduleCheckoutRecovery(after: checkoutTimeoutNanoseconds, trigger: .timeout)
    }

    @MainActor
    private func resetCheckoutProcessing() {
        checkoutRecoveryTask?.cancel()
        checkoutRecoveryTask = nil
        isCheckoutInProgress = false
        didLeaveAppForPayment = false
        boostButton.isEnabled = true
        boostButton.setTitle(boostButtonIdleTitle, for: .normal)
    }

    @MainActor
    private func presentSuccessState(boostConfirmed: Bool) {
        guard !didPresentSuccessState else { return }
        didPresentSuccessState = true
        resetCheckoutProcessing()

        let message = boostConfirmed
            ? "Your listing will stay pinned to the top of its category for 7 days."
            : "Your payment went through. We're still syncing the boost, so refresh your listing in a few seconds if it doesn't appear immediately."

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.showAlert(title: "Boosted! ⚡", message: message) { [weak self] in
                self?.onBoosted?()
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

        let boostConfirmed = await IAPManager.shared.hasBoostedItem(itemId: itemId)

        await MainActor.run {
            guard isCheckoutInProgress, !didPresentSuccessState else { return }

            if boostConfirmed {
                NotificationCenter.default.post(name: Notification.Name("itemsShouldRefresh"), object: nil)
                presentSuccessState(boostConfirmed: true)
                return
            }

            resetCheckoutProcessing()
            if trigger == .timeout {
                showAlert(
                    title: "Still Processing",
                    message: "We couldn't confirm the boost yet. If money was deducted, refresh your listing in a few seconds or try again."
                )
            }
        }
    }

    private func applyBoostToItem() async -> Bool {
        guard !itemId.isEmpty else { return false }

        do {
            struct BoostUpdate: Encodable {
                let is_boosted: Bool
                let boost_expires_at: String
            }

            let update = BoostUpdate(
                is_boosted: true,
                boost_expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600))
            )

            try await SupabaseManager.shared.client
                .from("items")
                .update(update)
                .eq("id", value: itemId)
                .execute()

            return true
        } catch {
            debugLog("[Boost] Failed to update item: \(error)")
            return false
        }
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
