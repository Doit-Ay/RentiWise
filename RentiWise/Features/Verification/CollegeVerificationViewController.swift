//
//  CollegeVerificationViewController.swift
//  RentiWise
//
//  Two-state screen: (1) email entry, (2) 6-digit OTP entry.
//  After successful verification, calls onVerificationComplete closure.
//

import UIKit
import Supabase

final class CollegeVerificationViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Callback
    var onVerificationComplete: (() -> Void)?

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let bodyColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    // MARK: - State
    private enum ScreenState { case emailEntry, otpEntry, success }
    private var currentState: ScreenState = .emailEntry
    private var enteredEmail: String = ""
    private var cooldownSeconds = 0
    private var cooldownTimer: Timer?

    // MARK: - UI Containers
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Email entry UI
    private let emailIcon = UIImageView()
    private let emailTitleLabel = UILabel()
    private let emailSubLabel = UILabel()
    private let emailTextField = UITextField()
    private let emailErrorLabel = UILabel()
    private let sendCodeButton = UIButton(type: .system)
    private let infoSection = UILabel()

    // OTP entry UI
    private let otpIcon = UIImageView()
    private let otpTitleLabel = UILabel()
    private let otpSubLabel = UILabel()
    private var otpFields: [UITextField] = []
    private let verifyButton = UIButton(type: .system)
    private let resendButton = UIButton(type: .system)
    private let cooldownLabel = UILabel()
    private let changeEmailButton = UIButton(type: .system)
    private let otpErrorLabel = UILabel()

    // Success UI
    private let successIcon = UIImageView()
    private let successTitle = UILabel()
    private let successSub = UILabel()

    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verify Your ID"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal
        setupScrollView()
        showEmailEntry()
    }

    deinit { cooldownTimer?.invalidate() }

    // MARK: - Scroll View Setup
    private func setupScrollView() {
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
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -32),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -64),
        ])
    }

    // MARK: - Email Entry State
    private func showEmailEntry() {
        currentState = .emailEntry
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Icon
        emailIcon.image = UIImage(systemName: "envelope.badge.shield.half.filled")
        emailIcon.tintColor = brandTeal
        emailIcon.contentMode = .scaleAspectFit
        emailIcon.translatesAutoresizingMaskIntoConstraints = false
        emailIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        emailIcon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        contentStack.addArrangedSubview(emailIcon)

        // Title
        emailTitleLabel.text = "Verify to Start Renting"
        emailTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        emailTitleLabel.textColor = bodyColor
        emailTitleLabel.textAlignment = .center
        contentStack.addArrangedSubview(emailTitleLabel)

        // Subtitle
        emailSubLabel.text = "Enter your email to verify your identity. College emails earn extra trust points! This is a one-time step."
        emailSubLabel.font = .systemFont(ofSize: 16)
        emailSubLabel.textColor = captionColor
        emailSubLabel.textAlignment = .center
        emailSubLabel.numberOfLines = 0
        contentStack.addArrangedSubview(emailSubLabel)

        // Email card
        let emailCard = makeCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let sectionHeader = UILabel()
        sectionHeader.text = "Email Address"
        sectionHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionHeader.textColor = captionColor
        cardStack.addArrangedSubview(sectionHeader)

        emailTextField.placeholder = "e.g. name@email.com or name@college.edu"
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.autocorrectionType = .no
        emailTextField.font = .systemFont(ofSize: 16)
        emailTextField.borderStyle = .none
        emailTextField.backgroundColor = bgColor
        emailTextField.layer.cornerRadius = 10
        emailTextField.layer.borderWidth = 1.5
        emailTextField.layer.borderColor = UIColor.systemGray4.cgColor
        emailTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        emailTextField.leftViewMode = .always
        emailTextField.delegate = self
        emailTextField.translatesAutoresizingMaskIntoConstraints = false
        emailTextField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        emailTextField.text = enteredEmail
        emailTextField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)
        cardStack.addArrangedSubview(emailTextField)

        emailErrorLabel.text = ""
        emailErrorLabel.font = .systemFont(ofSize: 13)
        emailErrorLabel.textColor = .systemRed
        emailErrorLabel.isHidden = true
        cardStack.addArrangedSubview(emailErrorLabel)

        emailCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: emailCard.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: emailCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: emailCard.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: emailCard.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(emailCard)
        emailCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Send button
        sendCodeButton.setTitle("Send Verification Code", for: .normal)
        sendCodeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendCodeButton.backgroundColor = brandTeal
        sendCodeButton.setTitleColor(.white, for: .normal)
        sendCodeButton.layer.cornerRadius = 12
        sendCodeButton.translatesAutoresizingMaskIntoConstraints = false
        sendCodeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        sendCodeButton.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(sendCodeButton)
        sendCodeButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        contentStack.addArrangedSubview(spinner)

        // Why we ask
        infoSection.text = "🔒 Why we ask\n\nVerifying your email builds trust with lenders. College/institute emails earn +25 bonus trust points and a 🎓 badge. We never share your email."
        infoSection.font = .systemFont(ofSize: 14)
        infoSection.textColor = captionColor
        infoSection.numberOfLines = 0
        infoSection.textAlignment = .center
        contentStack.addArrangedSubview(infoSection)
    }

    // MARK: - OTP Entry State
    private func showOTPEntry() {
        currentState = .otpEntry
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Icon
        otpIcon.image = UIImage(systemName: "envelope.badge.fill")
        otpIcon.tintColor = brandTeal
        otpIcon.contentMode = .scaleAspectFit
        otpIcon.translatesAutoresizingMaskIntoConstraints = false
        otpIcon.heightAnchor.constraint(equalToConstant: 60).isActive = true
        otpIcon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        contentStack.addArrangedSubview(otpIcon)

        // Title
        otpTitleLabel.text = "Check Your Email"
        otpTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        otpTitleLabel.textColor = bodyColor
        otpTitleLabel.textAlignment = .center
        contentStack.addArrangedSubview(otpTitleLabel)

        // Sub
        otpSubLabel.text = "We sent a 6-digit code to:\n\(enteredEmail)"
        otpSubLabel.font = .systemFont(ofSize: 16)
        otpSubLabel.textColor = captionColor
        otpSubLabel.textAlignment = .center
        otpSubLabel.numberOfLines = 0
        contentStack.addArrangedSubview(otpSubLabel)

        // OTP fields
        otpFields = (0..<6).map { _ in UITextField() }
        let otpStack = UIStackView(arrangedSubviews: otpFields)
        otpStack.axis = .horizontal
        otpStack.spacing = 8
        otpStack.distribution = .fillEqually
        otpStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, field) in otpFields.enumerated() {
            field.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
            field.textAlignment = .center
            field.keyboardType = .numberPad
            field.delegate = self
            field.tag = 100 + i
            field.layer.cornerRadius = 12
            field.layer.borderWidth = 2
            field.layer.borderColor = UIColor.systemGray4.cgColor
            field.backgroundColor = .white
            field.translatesAutoresizingMaskIntoConstraints = false
            field.addTarget(self, action: #selector(otpFieldChanged(_:)), for: .editingChanged)
            field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }

        contentStack.addArrangedSubview(otpStack)
        otpStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Error
        otpErrorLabel.text = ""
        otpErrorLabel.font = .systemFont(ofSize: 14, weight: .medium)
        otpErrorLabel.textColor = .systemRed
        otpErrorLabel.textAlignment = .center
        otpErrorLabel.isHidden = true
        contentStack.addArrangedSubview(otpErrorLabel)

        // Verify button
        verifyButton.setTitle("Verify Code", for: .normal)
        verifyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        verifyButton.backgroundColor = UIColor.systemGray4
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.layer.cornerRadius = 12
        verifyButton.isEnabled = false
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(verifyButton)
        verifyButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Spinner
        spinner.hidesWhenStopped = true
        contentStack.addArrangedSubview(spinner)

        // Resend row
        let resendStack = UIStackView()
        resendStack.axis = .vertical
        resendStack.spacing = 4
        resendStack.alignment = .center

        resendButton.setTitle("Resend Code", for: .normal)
        resendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        resendButton.setTitleColor(brandTeal, for: .normal)
        resendButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)
        resendButton.isEnabled = false
        resendStack.addArrangedSubview(resendButton)

        cooldownLabel.text = ""
        cooldownLabel.font = .systemFont(ofSize: 13)
        cooldownLabel.textColor = captionColor
        cooldownLabel.textAlignment = .center
        resendStack.addArrangedSubview(cooldownLabel)

        contentStack.addArrangedSubview(resendStack)

        // Change email button
        changeEmailButton.setTitle("← Use a different email", for: .normal)
        changeEmailButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        changeEmailButton.setTitleColor(captionColor, for: .normal)
        changeEmailButton.addTarget(self, action: #selector(changeEmailTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(changeEmailButton)

        // Start cooldown
        startCooldown()

        // Focus first field
        otpFields.first?.becomeFirstResponder()
    }

    // MARK: - Success State
    private func showSuccess() {
        currentState = .success
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        successIcon.image = UIImage(systemName: "checkmark.circle.fill")
        successIcon.tintColor = brandTeal
        successIcon.contentMode = .scaleAspectFit
        successIcon.translatesAutoresizingMaskIntoConstraints = false
        successIcon.heightAnchor.constraint(equalToConstant: 80).isActive = true
        successIcon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        successIcon.alpha = 0
        successIcon.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        contentStack.addArrangedSubview(successIcon)

        contentStack.addArrangedSubview(makeSpacer(20))

        successTitle.text = "Identity Verified!"
        successTitle.font = .systemFont(ofSize: 22, weight: .bold)
        successTitle.textColor = brandTeal
        successTitle.textAlignment = .center
        successTitle.alpha = 0
        contentStack.addArrangedSubview(successTitle)

        successSub.text = "You can now rent items on RentiWise."
        successSub.font = .systemFont(ofSize: 16)
        successSub.textColor = captionColor
        successSub.textAlignment = .center
        successSub.alpha = 0
        contentStack.addArrangedSubview(successSub)

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            self.successIcon.alpha = 1
            self.successIcon.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.3) {
            self.successTitle.alpha = 1
            self.successSub.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onVerificationComplete?()
            self?.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Actions

    @objc private func emailChanged() {
        emailTextField.layer.borderColor = brandTeal.cgColor
        emailErrorLabel.isHidden = true
    }

    @objc private func sendCodeTapped() {
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            showEmailError("Please enter your email")
            return
        }

        guard isValidEmail(email) else {
            showEmailError("Please enter a valid email address")
            return
        }

        enteredEmail = email
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        sendCodeButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                try await CollegeVerificationService.shared.sendVerificationOTP(email: email)
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.showOTPEntry()
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.sendCodeButton.isEnabled = true
                    self.showEmailError("Failed to send code: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func otpFieldChanged(_ field: UITextField) {
        guard let text = field.text else { return }
        if text.count >= 1 {
            field.text = String(text.prefix(1))
            let idx = field.tag - 100
            let nextIdx = idx + 1
            if nextIdx < otpFields.count {
                otpFields[nextIdx].becomeFirstResponder()
            } else {
                field.resignFirstResponder()
            }
        }
        field.layer.borderColor = text.isEmpty ? UIColor.systemGray4.cgColor : brandTeal.cgColor

        // Enable verify if all 6 filled
        let otp = otpFields.map { $0.text ?? "" }.joined()
        let allFilled = otp.count == 6
        verifyButton.isEnabled = allFilled
        verifyButton.backgroundColor = allFilled ? brandTeal : .systemGray4
    }

    @objc private func verifyTapped() {
        let otp = otpFields.map { $0.text ?? "" }.joined()
        guard otp.count == 6 else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        verifyButton.isEnabled = false
        spinner.startAnimating()
        otpErrorLabel.isHidden = true

        Task {
            let success = try await CollegeVerificationService.shared.verifyOTP(email: enteredEmail, otp: otp)
            if success {
                let userId = await SupabaseManager.shared.currentUserId() ?? ""
                try? await CollegeVerificationService.shared.markVerified(userId: userId, collegeEmail: enteredEmail)
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.showSuccess()
                }
            } else {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.verifyButton.isEnabled = true
                    self.verifyButton.backgroundColor = self.brandTeal
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    self.otpErrorLabel.text = "Incorrect code. Please try again."
                    self.otpErrorLabel.isHidden = false
                    self.shakeOTPFields()
                }
            }
        }
    }

    @objc private func resendTapped() {
        resendButton.isEnabled = false
        Task {
            try? await CollegeVerificationService.shared.sendVerificationOTP(email: enteredEmail)
            await MainActor.run { self.startCooldown() }
        }
    }

    @objc private func changeEmailTapped() {
        UIView.animate(withDuration: 0.25) {
            self.contentStack.alpha = 0
        } completion: { _ in
            self.contentStack.alpha = 1
            self.showEmailEntry()
        }
    }

    // MARK: - UITextFieldDelegate (OTP backspace)

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Handle email field normally
        guard textField.tag >= 100 else { return true }

        if string.isEmpty && (textField.text?.isEmpty ?? true) {
            let idx = textField.tag - 100
            let prevIdx = idx - 1
            if prevIdx >= 0 {
                otpFields[prevIdx].becomeFirstResponder()
                otpFields[prevIdx].text = ""
                otpFields[prevIdx].layer.borderColor = UIColor.systemGray4.cgColor
            }
            return false
        }
        return string.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let atIdx = email.firstIndex(of: "@")
        guard let at = atIdx else { return false }
        let afterAt = email[email.index(after: at)...]
        return afterAt.contains(".")
    }

    private func showEmailError(_ msg: String) {
        emailErrorLabel.text = msg
        emailErrorLabel.isHidden = false
        emailTextField.layer.borderColor = UIColor.systemRed.cgColor
    }

    private func shakeOTPFields() {
        for field in otpFields {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shake.values = [0, -10, 10, -8, 8, -4, 4, 0]
            shake.duration = 0.4
            field.layer.add(shake, forKey: "shake")
            field.layer.borderColor = UIColor.systemRed.cgColor
        }
    }

    private func startCooldown() {
        cooldownSeconds = 30
        resendButton.isEnabled = false
        cooldownLabel.text = "Resend available in \(cooldownSeconds)s"
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.cooldownSeconds -= 1
            if self.cooldownSeconds <= 0 {
                timer.invalidate()
                self.resendButton.isEnabled = true
                self.cooldownLabel.text = ""
            } else {
                self.cooldownLabel.text = "Resend available in \(self.cooldownSeconds)s"
            }
        }
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func makeSpacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }
}
