//
//  KYCVerificationViewController.swift
//  RentiWise
//
//  Created by admin99 on 23/03/26.
//

import UIKit
import Supabase

// MARK: - KYC Verification Screen

final class KYCVerificationViewController: UIViewController {

    /// Called when verification completes; passes the final status string.
    var onComplete: ((String) -> Void)?

    private let kycService = KYCService()
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    private let statusIconView = UIImageView()
    private let statusLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let verifyButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    private var currentStatus: String = "none"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Identity Verification"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        Task { await loadStatus() }
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Status icon
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusIconView)

        // Status label
        statusLabel.font = .systemFont(ofSize: 22, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Verify button
        verifyButton.setTitle("  Verify My Identity", for: .normal)
        verifyButton.setImage(UIImage(systemName: "person.badge.shield.checkmark"), for: .normal)
        verifyButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        verifyButton.backgroundColor = brandTeal
        verifyButton.tintColor = .white
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.layer.cornerRadius = 14
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        view.addSubview(verifyButton)

        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            statusIconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusIconView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            statusIconView.widthAnchor.constraint(equalToConstant: 80),
            statusIconView.heightAnchor.constraint(equalToConstant: 80),

            statusLabel.topAnchor.constraint(equalTo: statusIconView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            verifyButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            verifyButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            verifyButton.heightAnchor.constraint(equalToConstant: 52),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20),
        ])
    }

    // MARK: - Load status

    private func loadStatus() async {
        do {
            let status = try await kycService.fetchKYCStatus()
            await MainActor.run {
                currentStatus = status
                updateUI(for: status)
            }
        } catch {
            await MainActor.run {
                currentStatus = "none"
                updateUI(for: "none")
            }
        }
    }

    private func updateUI(for status: String) {
        switch status {
        case "approved":
            statusIconView.image = UIImage(systemName: "checkmark.seal.fill")
            statusIconView.tintColor = .systemGreen
            statusLabel.text = "Identity Verified"
            subtitleLabel.text = "Your identity has been successfully verified. You can now access all features."
            verifyButton.isHidden = true

        case "pending":
            statusIconView.image = UIImage(systemName: "clock.fill")
            statusIconView.tintColor = .systemOrange
            statusLabel.text = "Verification Pending"
            subtitleLabel.text = "Your documents are being reviewed. This usually takes a few minutes."
            verifyButton.isHidden = true

        case "declined":
            statusIconView.image = UIImage(systemName: "xmark.seal.fill")
            statusIconView.tintColor = .systemRed
            statusLabel.text = "Verification Declined"
            subtitleLabel.text = "Your verification was not successful. Please try again with valid documents."
            verifyButton.isHidden = false
            verifyButton.setTitle("  Try Again", for: .normal)

        default: // "none"
            statusIconView.image = UIImage(systemName: "person.badge.shield.checkmark")
            statusIconView.tintColor = brandTeal
            statusLabel.text = "Verify Your Identity"
            subtitleLabel.text = "Complete a quick identity check to unlock all features. You'll need your government-issued ID and a selfie."
            verifyButton.isHidden = false
        }
    }

    // MARK: - Verify action

    @objc private func verifyTapped() {
        showAlert(
            title: "Coming Soon",
            message: "Identity verification is being updated and will be available again shortly."
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
