//
//  UPIConfirmationViewController.swift
//  RentiWise
//
//  Shown after lender approves a request, before the OTP screen.
//  Displays rental summary, lender UPI ID, and "I have paid" confirmation.
//

import UIKit
import Supabase

final class UPIConfirmationViewController: UIViewController {

    // MARK: - Inputs (set before push)
    var requestId: String = ""
    var itemName: String = ""
    var itemId: String = ""
    var totalAmount: Double = 0
    var depositAmount: Double = 0
    var lenderUpiId: String = ""
    var lenderName: String = ""
    var lenderId: String = ""
    var borrowerId: String = ""
    var borrowerName: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var durationDays: Int = 1
    var pricePerDay: Double = 0
    var onPaymentConfirmed: (() -> Void)?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let confirmCheckbox = UIButton(type: .system)
    private let proceedButton = UIButton(type: .system)
    private var isConfirmed = false
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment"
        view.backgroundColor = .systemBackground
        setupUI()
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
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])

        // --- Rental Summary Card ---
        let summaryCard = makeCard()
        let summaryTitle = makeLabel("Rental Summary", style: .headline)

        let itemRow = makeDetailRow("Item", value: itemName)
        let totalRow = makeDetailRow("Rental Fee", value: String(format: "₹%.2f", totalAmount))
        let depositRow = makeDetailRow("Deposit", value: String(format: "₹%.2f", depositAmount))
        let grandTotal = totalAmount + depositAmount
        let totalPayRow = makeDetailRow("Total to Pay", value: String(format: "₹%.2f", grandTotal))
        totalPayRow.arrangedSubviews.compactMap { $0 as? UILabel }.last?.font = .systemFont(ofSize: 17, weight: .bold)

        let summaryStack = UIStackView(arrangedSubviews: [summaryTitle, itemRow, totalRow, depositRow, makeSeparator(), totalPayRow])
        summaryStack.axis = .vertical
        summaryStack.spacing = 12
        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(summaryStack)
        pinToCard(summaryStack, in: summaryCard)
        contentStack.addArrangedSubview(summaryCard)

        // --- Payment Instructions Card ---
        let payCard = makeCard()
        let payTitle = makeLabel("Pay via UPI", style: .headline)

        let upiLabel = makeLabel("Send payment to:", style: .subheadline)
        upiLabel.textColor = .secondaryLabel

        let upiIdLabel = makeLabel(lenderUpiId.isEmpty ? "UPI ID not set by lender" : lenderUpiId, style: .title2)
        upiIdLabel.textColor = brandTeal
        upiIdLabel.font = .monospacedSystemFont(ofSize: 20, weight: .semibold)

        let instructionLabel = makeLabel(
            "Open any UPI app (GPay, PhonePe, Paytm, etc.) and send ₹\(String(format: "%.2f", grandTotal)) to \(lenderName).",
            style: .body
        )
        instructionLabel.textColor = .secondaryLabel

        // "Open UPI App" button
        let openUPIButton = UIButton(type: .system)
        openUPIButton.setTitle("Open UPI App", for: .normal)
        openUPIButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        openUPIButton.backgroundColor = brandTeal.withAlphaComponent(0.15)
        openUPIButton.setTitleColor(brandTeal, for: .normal)
        openUPIButton.layer.cornerRadius = 12
        openUPIButton.translatesAutoresizingMaskIntoConstraints = false
        openUPIButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        openUPIButton.addTarget(self, action: #selector(openUPIApp), for: .touchUpInside)

        let payStack = UIStackView(arrangedSubviews: [payTitle, upiLabel, upiIdLabel, instructionLabel, openUPIButton])
        payStack.axis = .vertical
        payStack.spacing = 12
        payStack.translatesAutoresizingMaskIntoConstraints = false
        payCard.addSubview(payStack)
        pinToCard(payStack, in: payCard)
        contentStack.addArrangedSubview(payCard)

        // --- Confirmation ---
        let confirmRow = UIStackView()
        confirmRow.axis = .horizontal
        confirmRow.spacing = 12
        confirmRow.alignment = .center

        confirmCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
        confirmCheckbox.tintColor = brandTeal
        confirmCheckbox.addTarget(self, action: #selector(toggleConfirmation), for: .touchUpInside)
        confirmCheckbox.translatesAutoresizingMaskIntoConstraints = false
        confirmCheckbox.widthAnchor.constraint(equalToConstant: 28).isActive = true
        confirmCheckbox.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let confirmLabel = makeLabel(
            "I confirm I have paid ₹\(String(format: "%.2f", grandTotal)) to \(lenderUpiId)",
            style: .subheadline
        )
        confirmLabel.numberOfLines = 0

        confirmRow.addArrangedSubview(confirmCheckbox)
        confirmRow.addArrangedSubview(confirmLabel)
        contentStack.addArrangedSubview(confirmRow)

        // --- Proceed Button ---
        proceedButton.setTitle("Proceed to Pickup Code", for: .normal)
        proceedButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        proceedButton.backgroundColor = .systemGray4
        proceedButton.setTitleColor(.white, for: .normal)
        proceedButton.layer.cornerRadius = 14
        proceedButton.isEnabled = false
        proceedButton.translatesAutoresizingMaskIntoConstraints = false
        proceedButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        proceedButton.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(proceedButton)

        // Info banner
        let infoBanner = makeLabel(
            "⚠️ Rentiwise does not process payments. Payments are settled directly between users via UPI.",
            style: .caption1
        )
        infoBanner.textColor = .secondaryLabel
        infoBanner.textAlignment = .center
        contentStack.addArrangedSubview(infoBanner)
    }

    // MARK: - Actions
    @objc private func openUPIApp() {
        let grandTotal = totalAmount + depositAmount
        let upiString = "upi://pay?pa=\(lenderUpiId)&pn=\(lenderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&am=\(String(format: "%.2f", grandTotal))&cu=INR"
        if let url = URL(string: upiString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let alert = UIAlertController(title: "No UPI App", message: "No UPI app is installed. Please pay manually and confirm below.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func toggleConfirmation() {
        isConfirmed.toggle()
        let imageName = isConfirmed ? "checkmark.square.fill" : "square"
        confirmCheckbox.setImage(UIImage(systemName: imageName), for: .normal)
        proceedButton.isEnabled = isConfirmed
        proceedButton.backgroundColor = isConfirmed ? brandTeal : .systemGray4
    }

    @objc private func proceedTapped() {
        guard isConfirmed else { return }
        proceedButton.isEnabled = false

        Task {
            do {
                // Update request: payment_confirmed_by_borrower = true
                struct ConfirmUpdate: Encodable { let payment_confirmed_by_borrower: Bool }
                _ = try await SupabaseManager.shared.client
                    .from("requests")
                    .update(ConfirmUpdate(payment_confirmed_by_borrower: true))
                    .eq("id", value: requestId)
                    .execute()

                await MainActor.run {
                    self.onPaymentConfirmed?()
                    // Navigate to Rental Agreement flow
                    let agreementVC = RentalAgreementViewController()
                    agreementVC.requestId = self.requestId
                    agreementVC.itemName = self.itemName
                    agreementVC.itemId = self.itemId
                    agreementVC.lenderId = self.lenderId
                    agreementVC.borrowerId = self.borrowerId
                    agreementVC.lenderName = self.lenderName
                    agreementVC.borrowerName = self.borrowerName
                    agreementVC.startDate = self.startDate
                    agreementVC.endDate = self.endDate
                    agreementVC.durationDays = self.durationDays
                    agreementVC.pricePerDay = self.pricePerDay
                    agreementVC.totalRentalPrice = self.totalAmount
                    agreementVC.depositAmount = self.depositAmount
                    self.navigationController?.pushViewController(agreementVC, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.proceedButton.isEnabled = true
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - Helpers
    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func pinToCard(_ stack: UIStackView, in card: UIView) {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.numberOfLines = 0
        return label
    }

    private func makeDetailRow(_ title: String, value: String) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .medium)
        valueLabel.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.axis = .horizontal
        row.distribution = .fill
        return row
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return sep
    }
}
