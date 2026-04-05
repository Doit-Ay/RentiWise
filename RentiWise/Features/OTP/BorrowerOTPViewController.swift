//
//  BorrowerOTPViewController.swift
//  RentiWise
//
//  Shown to the borrower after the lender confirms UPI payment receipt.
//  Loads or regenerates the request-backed 6-digit pickup OTP for the borrower
//  to show the lender at pickup.
//

import UIKit
final class BorrowerOTPViewController: UIViewController {

    // MARK: - Inputs (set before push)
    var requestId: String = ""
    var lenderName: String = ""

    // MARK: - UI
    private let otpLabel = UILabel()
    private let instructionLabel = UILabel()
    private let regenerateButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    private var cooldownTimer: Timer?
    private var cooldownSeconds = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pickup OTP"
        view.backgroundColor = .systemBackground
        setupUI()
        loadPickupOTP()
    }

    deinit {
        cooldownTimer?.invalidate()
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

        // Regenerate button
        regenerateButton.setTitle("Regenerate Code", for: .normal)
        regenerateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        regenerateButton.tintColor = brandTeal
        regenerateButton.addTarget(self, action: #selector(regenerateTapped), for: .touchUpInside)
        regenerateButton.translatesAutoresizingMaskIntoConstraints = false

        // Status label (for cooldown)
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [instructionLabel, otpLabel, spinner, regenerateButton, statusLabel])
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

    private func loadPickupOTP() {
        spinner.startAnimating()
        otpLabel.text = "----"
        statusLabel.text = "Checking payment confirmation..."
        regenerateButton.isHidden = true
        regenerateButton.isEnabled = false

        Task {
            do {
                let paymentState = try await RentalPaymentStateService.shared.fetch(requestId: requestId)
                guard paymentState.lenderConfirmedReceived else {
                    await MainActor.run {
                        self.spinner.stopAnimating()
                        self.instructionLabel.text = "Your pickup OTP unlocks after the lender confirms they received your UPI payment."
                        self.statusLabel.text = "Waiting for lender payment confirmation"
                        self.regenerateButton.isHidden = true
                    }
                    return
                }

                try await self.displayOrCreatePickupOTP()
            } catch {
                await MainActor.run {
                    if PickupOTPService.isManualConfirmationRequiredError(error) {
                        self.showManualPickupFallback(message: error.localizedDescription)
                        return
                    }
                    self.spinner.stopAnimating()
                    self.otpLabel.text = "Error"
                    self.statusLabel.text = error.localizedDescription
                    self.regenerateButton.isHidden = false
                    self.regenerateButton.isEnabled = true
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
        regenerateButton.isHidden = true
        regenerateButton.isEnabled = false
    }

    private func displayOrCreatePickupOTP() async throws {
        let code = try await PickupOTPService.shared.loadOrCreatePickupCode(requestId: requestId)
        await MainActor.run {
            self.spinner.stopAnimating()
            self.regenerateButton.isHidden = false
            self.regenerateButton.isEnabled = true
            self.statusLabel.text = nil
            self.otpLabel.text = code
        }
    }

    // MARK: - Generate OTP from request row
    private func generateOTP() {
        spinner.startAnimating()
        otpLabel.text = "----"
        regenerateButton.isHidden = false
        regenerateButton.isEnabled = false
        statusLabel.text = "Generating pickup code..."

        Task {
            do {
                let code = try await PickupOTPService.shared.regeneratePickupCode(requestId: requestId)

                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.otpLabel.text = code
                    self.startCooldown()
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.otpLabel.text = "Error"
                    self.statusLabel.text = error.localizedDescription
                    self.regenerateButton.isEnabled = true
                }
            }
        }
    }

    @objc private func regenerateTapped() {
        generateOTP()
    }

    // MARK: - Cooldown
    private func startCooldown() {
        cooldownSeconds = 30
        regenerateButton.isEnabled = false
        statusLabel.text = "Regenerate available in \(cooldownSeconds)s"
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.cooldownSeconds -= 1
            if self.cooldownSeconds <= 0 {
                timer.invalidate()
                self.regenerateButton.isEnabled = true
                self.statusLabel.text = ""
            } else {
                self.statusLabel.text = "Regenerate available in \(self.cooldownSeconds)s"
            }
        }
    }
}
