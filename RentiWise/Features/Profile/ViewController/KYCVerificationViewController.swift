//
//  KYCVerificationViewController.swift
//  RentiWise
//
//  Created by admin99 on 23/03/26.
//

import UIKit
import SwiftUI
import DiditSDK
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
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private var currentStatus: String = "none"

    // Didit Workflow ID
    private let workflowId = "52b212b3-1bac-46c4-a647-fb6b042157d7"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Identity Verification"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        addDigitVerificationModifier()
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

    // MARK: - Didit SwiftUI bridge

    /// Embeds an invisible SwiftUI view that carries the `.diditVerification` modifier.
    private func addDigitVerificationModifier() {
        let bridge = DiditBridgeView { [weak self] result in
            self?.handleVerificationResult(result)
        }
        let hostingVC = UIHostingController(rootView: bridge)
        hostingVC.view.frame = .zero
        hostingVC.view.isHidden = true
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
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
        activityIndicator.startAnimating()
        verifyButton.isEnabled = false

        Task {
            do {
                // Call our Supabase Edge Function to create a Didit session
                let session = try await SupabaseManager.shared.client.auth.session
                let supabaseUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
                let functionUrl = "\(supabaseUrl)/functions/v1/create-kyc-session"

                var request = URLRequest(url: URL(string: functionUrl)!)
                request.httpMethod = "POST"
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

                // Get anon key from Info.plist
                let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
                request.setValue(anonKey, forHTTPHeaderField: "apikey")

                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "KYC", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }

                guard httpResponse.statusCode == 200 else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    debugLog("[KYC] Edge function returned status \(httpResponse.statusCode)")
                    throw NSError(domain: "KYC", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to create session: \(errorBody)"])
                }

                // Parse the session token
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let sessionToken = json?["session_token"] as? String ?? ""

                if sessionToken.isEmpty {
                    throw NSError(domain: "KYC", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "No session token returned"])
                }

                // Use Option A: pass the session token to the SDK
                await MainActor.run {
                    #if DEBUG
                    let config = DiditSdk.Configuration(loggingEnabled: true)
                    #else
                    let config = DiditSdk.Configuration(loggingEnabled: false)
                    #endif
                    DiditSdk.shared.startVerification(
                        token: sessionToken,
                        configuration: config
                    )
                }
            } catch {
                await MainActor.run {
                    activityIndicator.stopAnimating()
                    verifyButton.isEnabled = true
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Handle result

    private func handleVerificationResult(_ result: VerificationResult) {
        Task { @MainActor in
            activityIndicator.stopAnimating()
            verifyButton.isEnabled = true

            switch result {
            case .completed(let session):
                let statusString: String
                switch session.status {
                case .approved:
                    statusString = "approved"
                case .declined:
                    statusString = "declined"
                case .pending:
                    statusString = "pending"
                @unknown default:
                    statusString = "pending"
                }

                // Save to Supabase
                Task {
                    try? await kycService.updateKYCStatus(
                        sessionId: session.sessionId,
                        status: statusString
                    )
                }

                currentStatus = statusString
                updateUI(for: statusString)
                onComplete?(statusString)

                if statusString == "approved" {
                    showAlert(title: "Verified! ✅", message: "Your identity has been successfully verified.")
                } else if statusString == "declined" {
                    showAlert(title: "Verification Failed", message: "Please try again with valid documents.")
                } else {
                    showAlert(title: "Under Review", message: "Your documents are being reviewed.")
                }

            case .cancelled:
                showAlert(title: "Cancelled", message: "You cancelled the verification process. You can try again anytime.")

            case .failed(let error, _):
                showAlert(title: "Error", message: error.localizedDescription)
            @unknown default:
                showAlert(title: "Verification Update", message: "Verification finished with a status this build does not recognise yet.")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SwiftUI Bridge View

/// An invisible SwiftUI view that carries the `.diditVerification` result handler.
private struct DiditBridgeView: View {
    let onResult: (VerificationResult) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .diditVerification { result in
                onResult(result)
            }
    }
}
