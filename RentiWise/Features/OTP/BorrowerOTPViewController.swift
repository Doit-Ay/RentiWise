//
//  BorrowerOTPViewController.swift
//  RentiWise
//
//  Shown to the borrower after payment is confirmed (status = succeeded).
//  Displays the 6-digit pickup OTP that the borrower shows to the lender at pickup.
//  The OTP is auto-generated when payment succeeds and stored in the payments table.
//

import UIKit
final class BorrowerOTPViewController: UIViewController {

    // MARK: - Inputs (set before push)
    var requestId: String = ""
    var lenderName: String = ""

    // MARK: - UI
    private let otpLabel = UILabel()
    private let instructionLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pickup OTP"
        view.backgroundColor = .systemBackground
        setupUI()
        loadPickupOTP()
    }



    // MARK: - UI Setup
    private func setupUI() {
        // Instruction
        instructionLabel.text = "Show this code to \(lenderName) when you meet for pickup"
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        // OTP
        otpLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        otpLabel.textAlignment = .center
        otpLabel.textColor = brandTeal
        otpLabel.text = "----"
        otpLabel.translatesAutoresizingMaskIntoConstraints = false



        // Status label (for cooldown)
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [instructionLabel, otpLabel, spinner, statusLabel])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Load Pickup OTP
    private func loadPickupOTP() {
        spinner.startAnimating()
        otpLabel.text = "----"
        statusLabel.text = "Loading pickup code..."

        Task {
            do {
                let code = try await PickupOTPService.shared.loadOrCreatePickupCode(requestId: requestId)
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.otpLabel.text = code
                    self.statusLabel.text = "Show this code to the lender at pickup."
                }
            } catch {
                await MainActor.run {
                    if PickupOTPService.isManualConfirmationRequiredError(error) {
                        self.showManualPickupFallback(message: error.localizedDescription)
                        return
                    }
                    self.spinner.stopAnimating()
                    self.otpLabel.text = "Error"
                    self.statusLabel.text = error.localizedDescription
                }
            }
        }
    }

    private func showManualPickupFallback(message: String) {
        spinner.stopAnimating()
        title = "Pickup Confirmation"
        instructionLabel.text = "Meet \(lenderName) for pickup. Pickup codes are not available on this backend, so the lender will confirm the handoff directly in their app."
        otpLabel.font = .systemFont(ofSize: 34, weight: .bold)
        otpLabel.text = "No Code"
        statusLabel.text = message
    }
}
