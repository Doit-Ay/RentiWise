//
//  PhoneOTPViewController.swift
//  RentiWise
//
//  Created by admin99 on 22/03/26.
//

import UIKit

@MainActor
final class PhoneOTPViewController: UIViewController {

    // MARK: - Public config

    /// Pre-fill the phone number (digits only, no country code).
    var prefillPhone: String = ""

    /// Called after successful verification **or** skip.
    /// Bool = true if verified, false if skipped.
    var onComplete: ((_ verified: Bool) -> Void)?

    // MARK: - Private state

    private let otpService = PhoneOTPService()
    private var otpSent = false
    private var fullPhone = ""   // E.164

    // MARK: - Brand color

    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - UI elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let phoneIcon = UIImageView()
    private let countryCodeLabel = UILabel()
    private let phoneField = UITextField()
    private let phoneContainer = UIView()
    private let sendOTPButton = UIButton(type: .system)

    private let otpTitleLabel = UILabel()
    private let otpField = UITextField()
    private let verifyButton = UIButton(type: .system)
    private let resendButton = UIButton(type: .system)

    private let otpStack = UIStackView()
    private let skipButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verify Phone"
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        buildUI()
        prefillPhoneField()
    }

    // MARK: - Navigation

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Skip",
            style: .plain,
            target: self,
            action: #selector(skipTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .secondaryLabel
    }

    // MARK: - Build UI

    private func buildUI() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Content stack
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])

        // --- Phone icon ---
        phoneIcon.image = UIImage(systemName: "phone.badge.checkmark")
        phoneIcon.tintColor = brandTeal
        phoneIcon.contentMode = .scaleAspectFit
        phoneIcon.translatesAutoresizingMaskIntoConstraints = false
        phoneIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // --- Title ---
        titleLabel.text = "Verify Your Phone"
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // --- Subtitle ---
        subtitleLabel.text = "We'll send a 6-digit code to your phone number via SMS to verify it."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // --- Phone input container (country code + field) ---
        phoneContainer.translatesAutoresizingMaskIntoConstraints = false
        phoneContainer.layer.cornerRadius = 12
        phoneContainer.layer.borderWidth = 1
        phoneContainer.layer.borderColor = UIColor.separator.cgColor
        phoneContainer.backgroundColor = .secondarySystemBackground

        countryCodeLabel.text = "+91"
        countryCodeLabel.font = .systemFont(ofSize: 17, weight: .medium)
        countryCodeLabel.textColor = .label
        countryCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        countryCodeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        phoneField.placeholder = "Phone Number"
        phoneField.keyboardType = .phonePad
        phoneField.font = .systemFont(ofSize: 17)
        phoneField.translatesAutoresizingMaskIntoConstraints = false

        phoneContainer.addSubview(countryCodeLabel)
        phoneContainer.addSubview(divider)
        phoneContainer.addSubview(phoneField)

        NSLayoutConstraint.activate([
            phoneContainer.heightAnchor.constraint(equalToConstant: 52),

            countryCodeLabel.leadingAnchor.constraint(equalTo: phoneContainer.leadingAnchor, constant: 16),
            countryCodeLabel.centerYAnchor.constraint(equalTo: phoneContainer.centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: countryCodeLabel.trailingAnchor, constant: 12),
            divider.topAnchor.constraint(equalTo: phoneContainer.topAnchor, constant: 12),
            divider.bottomAnchor.constraint(equalTo: phoneContainer.bottomAnchor, constant: -12),

            phoneField.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 12),
            phoneField.trailingAnchor.constraint(equalTo: phoneContainer.trailingAnchor, constant: -16),
            phoneField.centerYAnchor.constraint(equalTo: phoneContainer.centerYAnchor)
        ])

        // --- Send OTP button ---
        sendOTPButton.setTitle("Send OTP", for: .normal)
        sendOTPButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        sendOTPButton.backgroundColor = brandTeal
        sendOTPButton.setTitleColor(.white, for: .normal)
        sendOTPButton.layer.cornerRadius = 12
        sendOTPButton.translatesAutoresizingMaskIntoConstraints = false
        sendOTPButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        sendOTPButton.addTarget(self, action: #selector(sendOTPTapped), for: .touchUpInside)

        // --- OTP section (hidden initially) ---
        otpTitleLabel.text = "Enter the 6-digit code sent to your phone"
        otpTitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        otpTitleLabel.textColor = .secondaryLabel
        otpTitleLabel.textAlignment = .center
        otpTitleLabel.numberOfLines = 0

        otpField.placeholder = "• • • • • •"
        otpField.keyboardType = .numberPad
        otpField.textAlignment = .center
        otpField.font = .systemFont(ofSize: 24, weight: .medium)
        otpField.layer.cornerRadius = 12
        otpField.layer.borderWidth = 1
        otpField.layer.borderColor = UIColor.separator.cgColor
        otpField.backgroundColor = .secondarySystemBackground
        otpField.translatesAutoresizingMaskIntoConstraints = false
        otpField.heightAnchor.constraint(equalToConstant: 52).isActive = true

        verifyButton.setTitle("Verify", for: .normal)
        verifyButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        verifyButton.backgroundColor = brandTeal
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.layer.cornerRadius = 12
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)

        resendButton.setTitle("Resend Code", for: .normal)
        resendButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        resendButton.setTitleColor(brandTeal, for: .normal)
        resendButton.addTarget(self, action: #selector(sendOTPTapped), for: .touchUpInside)

        otpStack.axis = .vertical
        otpStack.spacing = 16
        otpStack.alignment = .fill
        otpStack.addArrangedSubview(otpTitleLabel)
        otpStack.addArrangedSubview(otpField)
        otpStack.addArrangedSubview(verifyButton)
        otpStack.addArrangedSubview(resendButton)
        otpStack.isHidden = true

        // --- Activity indicator ---
        activityIndicator.hidesWhenStopped = true

        // --- Assemble ---
        contentStack.addArrangedSubview(phoneIcon)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(phoneContainer)
        contentStack.addArrangedSubview(sendOTPButton)
        contentStack.addArrangedSubview(otpStack)
        contentStack.addArrangedSubview(activityIndicator)

        // Extra spacing
        contentStack.setCustomSpacing(8, after: phoneIcon)
        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(24, after: subtitleLabel)
        contentStack.setCustomSpacing(16, after: phoneContainer)
        contentStack.setCustomSpacing(24, after: sendOTPButton)
    }

    // MARK: - Prefill

    private func prefillPhoneField() {
        let digits = prefillPhone.filter { $0.isNumber }
        // If the number starts with 91 and is long, strip the country code
        if digits.hasPrefix("91") && digits.count > 10 {
            phoneField.text = String(digits.dropFirst(2))
        } else {
            phoneField.text = digits
        }
    }

    // MARK: - Actions

    @objc private func sendOTPTapped() {
        let raw = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let digits = raw.filter { $0.isNumber }

        guard digits.count >= 10 else {
            presentAlert(title: "Invalid Number", message: "Please enter a valid phone number (at least 10 digits).")
            return
        }

        // Build E.164
        if digits.hasPrefix("91") && digits.count > 10 {
            fullPhone = "+\(digits)"
        } else {
            fullPhone = "+91\(digits)"
        }

        setLoading(true)

        Task {
            do {
                try await otpService.sendOTP(phone: fullPhone)
                await MainActor.run {
                    setLoading(false)
                    showOTPSection()
                    presentAlert(title: "OTP Sent!", message: "A 6-digit code has been sent to \(fullPhone).")
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    presentAlert(title: "Failed to Send OTP", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func verifyTapped() {
        let code = otpField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            presentAlert(title: "Invalid Code", message: "Please enter the 6-digit code you received.")
            return
        }

        setLoading(true)

        Task {
            do {
                try await otpService.verifyOTP(phone: fullPhone, token: code)
                try await otpService.markPhoneVerified(phone: fullPhone)
                await MainActor.run {
                    setLoading(false)
                    onComplete?(true)
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    presentAlert(title: "Verification Failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func skipTapped() {
        onComplete?(false)
    }

    // MARK: - UI Helpers

    private func showOTPSection() {
        otpSent = true
        sendOTPButton.setTitle("Resend OTP", for: .normal)
        sendOTPButton.backgroundColor = .systemGray4
        sendOTPButton.setTitleColor(.label, for: .normal)

        phoneField.isEnabled = false
        phoneField.textColor = .secondaryLabel

        otpStack.isHidden = false
        otpField.becomeFirstResponder()
    }

    private func setLoading(_ loading: Bool) {
        sendOTPButton.isEnabled = !loading
        verifyButton.isEnabled = !loading
        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
