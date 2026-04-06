//
//  LenderReturnOTPViewController.swift
//  RentiWise
//
//  Shown to the lender when the rental is active and items need to be returned.
//  Generates a return OTP via the `generate-otp` Edge Function with type = "return".
//

import UIKit
import Supabase

final class LenderReturnOTPViewController: UIViewController {

    // MARK: - Inputs
    var requestId: String = ""
    var borrowerName: String = ""
    var onCodeGenerated: (() -> Void)?

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
        title = "Return Code"
        view.backgroundColor = .systemBackground
        setupUI()
        generateOTP()
    }

    deinit {
        cooldownTimer?.invalidate()
    }

    // MARK: - UI Setup
    private func setupUI() {
        instructionLabel.text = "Show this code to \(borrowerName) when they return the item"
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        otpLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        otpLabel.textAlignment = .center
        otpLabel.textColor = brandTeal
        otpLabel.text = "----"
        otpLabel.translatesAutoresizingMaskIntoConstraints = false

        regenerateButton.setTitle("Regenerate Code", for: .normal)
        regenerateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        regenerateButton.tintColor = brandTeal
        regenerateButton.addTarget(self, action: #selector(regenerateTapped), for: .touchUpInside)
        regenerateButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

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

    // MARK: - Generate Return OTP
    private func generateOTP() {
        spinner.startAnimating()
        otpLabel.text = "----"
        statusLabel.text = "Generating return code..."
        regenerateButton.isEnabled = false

        Task {
            do {
                let result: GenerateOTPResponse = try await SupabaseManager.shared.client.functions
                    .invoke("generate-otp", options: .init(body: GenerateReturnOTPRequest(request_id: requestId, type: "return")))

                await MainActor.run {
                    if let errorMessage = result.error?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !errorMessage.isEmpty {
                        self.spinner.stopAnimating()
                        self.otpLabel.text = "Error"
                        self.statusLabel.text = errorMessage
                        self.regenerateButton.isEnabled = true
                        return
                    }

                    self.spinner.stopAnimating()
                    self.otpLabel.text = result.otp
                    self.onCodeGenerated?()
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

// MARK: - Models
private struct GenerateReturnOTPRequest: Encodable {
    let request_id: String
    let type: String
}

private struct GenerateOTPResponse: Decodable {
    let otp: String
    let success: Bool?
    let error: String?
    let expires_at: String?
}
