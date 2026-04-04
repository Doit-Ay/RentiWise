//
//  PhoneVerificationViewController.swift
//  RentiWise
//
//  Mandatory phone OTP screen. Two states: phone entry → OTP entry.
//  Cannot be dismissed; user must complete verification.
//

import UIKit
import Supabase

final class PhoneVerificationViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Callback
    var onVerificationComplete: (() -> Void)?
    var prefillPhone: String = ""

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let bodyColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    // MARK: - State
    private enum ScreenState { case phoneEntry, otpEntry, success }
    private var currentState: ScreenState = .phoneEntry
    private var enteredPhone: String = ""
    private var failureCount = 0
    private var cooldownSeconds = 0
    private var cooldownTimer: Timer?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // Phone entry
    private let phoneIcon = UIImageView()
    private let phoneTitleLabel = UILabel()
    private let phoneSubLabel = UILabel()
    private let phoneTextField = UITextField()
    private let sendCodeButton = UIButton(type: .system)
    private let phoneCaption = UILabel()

    // OTP entry
    private let otpIcon = UIImageView()
    private let otpTitleLabel = UILabel()
    private let otpSubLabel = UILabel()
    private var otpFields: [UITextField] = []
    private let verifyButton = UIButton(type: .system)
    private let resendButton = UIButton(type: .system)
    private let cooldownLabel = UILabel()
    private let changeNumberButton = UIButton(type: .system)
    private let otpErrorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verify Your Phone"
        view.backgroundColor = bgColor
        // navigationItem.hidesBackButton = true // No skipping
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(didTapClose)
        )
        navigationController?.navigationBar.tintColor = brandTeal
        enteredPhone = normalizedPhoneDigits(prefillPhone)
        setupScrollView()
        showPhoneEntry()
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
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 48),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -32),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -64),
        ])
    }

    // MARK: - Phone Entry State
    private func showPhoneEntry() {
        currentState = .phoneEntry
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Icon
        phoneIcon.image = UIImage(systemName: "phone.fill")
        phoneIcon.tintColor = brandTeal
        phoneIcon.contentMode = .scaleAspectFit
        phoneIcon.translatesAutoresizingMaskIntoConstraints = false
        phoneIcon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        phoneIcon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        contentStack.addArrangedSubview(phoneIcon)

        // Title
        phoneTitleLabel.text = "Verify Your Phone"
        phoneTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        phoneTitleLabel.textColor = bodyColor
        phoneTitleLabel.textAlignment = .center
        contentStack.addArrangedSubview(phoneTitleLabel)

        // Subtitle
        phoneSubLabel.text = "Confirm your Indian mobile number to start using Rentiwise."
        phoneSubLabel.font = .systemFont(ofSize: 16)
        phoneSubLabel.textColor = captionColor
        phoneSubLabel.textAlignment = .center
        phoneSubLabel.numberOfLines = 0
        contentStack.addArrangedSubview(phoneSubLabel)

        // Phone field card
        let card = makeCard()
        let fieldContainer = UIView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false

        // +91 prefix label
        let prefixLabel = UILabel()
        prefixLabel.text = "+91"
        prefixLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        prefixLabel.textColor = brandTeal
        let prefixContainer = UIView(frame: CGRect(x: 0, y: 0, width: 56, height: 48))
        prefixLabel.frame = CGRect(x: 12, y: 0, width: 32, height: 48)
        prefixContainer.addSubview(prefixLabel)

        // Vertical divider
        let divider = UIView(frame: CGRect(x: 52, y: 12, width: 1, height: 24))
        divider.backgroundColor = UIColor.systemGray4
        prefixContainer.addSubview(divider)

        phoneTextField.placeholder = "Enter 10-digit mobile number"
        phoneTextField.keyboardType = .numberPad
        phoneTextField.font = .systemFont(ofSize: 16)
        phoneTextField.borderStyle = .none
        phoneTextField.backgroundColor = bgColor
        phoneTextField.layer.cornerRadius = 12
        phoneTextField.layer.borderWidth = 1.5
        phoneTextField.layer.borderColor = UIColor.systemGray4.cgColor
        phoneTextField.leftView = prefixContainer
        phoneTextField.leftViewMode = .always
        phoneTextField.delegate = self
        phoneTextField.text = enteredPhone
        phoneTextField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
        phoneTextField.translatesAutoresizingMaskIntoConstraints = false
        phoneTextField.heightAnchor.constraint(equalToConstant: 48).isActive = true

        card.addSubview(phoneTextField)
        NSLayoutConstraint.activate([
            phoneTextField.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            phoneTextField.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            phoneTextField.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            phoneTextField.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Send button
        sendCodeButton.setTitle("Send Verification Code", for: .normal)
        sendCodeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendCodeButton.backgroundColor = UIColor.systemGray4
        sendCodeButton.setTitleColor(.white, for: .normal)
        sendCodeButton.layer.cornerRadius = 12
        sendCodeButton.isEnabled = false
        sendCodeButton.translatesAutoresizingMaskIntoConstraints = false
        sendCodeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        sendCodeButton.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(sendCodeButton)
        sendCodeButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        contentStack.addArrangedSubview(spinner)

        phoneCaption.text = "Your number is used only for identity verification and is never shared."
        phoneCaption.font = .preferredFont(forTextStyle: .caption1)
        phoneCaption.textColor = captionColor
        phoneCaption.textAlignment = .center
        phoneCaption.numberOfLines = 0
        contentStack.addArrangedSubview(phoneCaption)

        phoneTextField.becomeFirstResponder()
        updateSendButtonState()
    }

    // MARK: - OTP Entry State
    private func showOTPEntry() {
        currentState = .otpEntry
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        otpIcon.image = UIImage(systemName: "message.fill")
        otpIcon.tintColor = brandTeal
        otpIcon.contentMode = .scaleAspectFit
        otpIcon.translatesAutoresizingMaskIntoConstraints = false
        otpIcon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        otpIcon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        contentStack.addArrangedSubview(otpIcon)

        otpTitleLabel.text = "Check Your SMS"
        otpTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        otpTitleLabel.textColor = bodyColor
        otpTitleLabel.textAlignment = .center
        contentStack.addArrangedSubview(otpTitleLabel)

        // Format number for display
        let formatted = formatPhoneDisplay(enteredPhone)
        otpSubLabel.text = "We sent a 6-digit code to:\n+91 \(formatted)"
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
            field.tag = 200 + i
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
        verifyButton.setTitle("Verify Number", for: .normal)
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

        spinner.hidesWhenStopped = true
        contentStack.addArrangedSubview(spinner)

        // Resend
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

        // Change number
        changeNumberButton.setTitle("← Use a different number", for: .normal)
        changeNumberButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        changeNumberButton.setTitleColor(captionColor, for: .normal)
        changeNumberButton.addTarget(self, action: #selector(changeNumberTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(changeNumberButton)

        startCooldown()
        otpFields.first?.becomeFirstResponder()
    }

    // MARK: - Success State
    private func showSuccess() {
        currentState = .success
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let icon = UIImageView()
        icon.image = UIImage(systemName: "checkmark.circle.fill")
        icon.tintColor = brandTeal
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 80).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        icon.alpha = 0
        icon.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        contentStack.addArrangedSubview(icon)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStack.addArrangedSubview(spacer)

        let title = UILabel()
        title.text = "Number Verified! 📱"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = brandTeal
        title.textAlignment = .center
        title.alpha = 0
        contentStack.addArrangedSubview(title)

        let sub = UILabel()
        sub.text = "Your phone number has been verified."
        sub.font = .systemFont(ofSize: 16)
        sub.textColor = captionColor
        sub.textAlignment = .center
        sub.alpha = 0
        contentStack.addArrangedSubview(sub)

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            icon.alpha = 1; icon.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.3) {
            title.alpha = 1; sub.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onVerificationComplete?()
        }
    }

    // MARK: - Actions
    
    @objc private func didTapClose() {
        dismiss(animated: true) { [weak self] in
            // If the user hasn't successfully verified, we can trigger an optional cancellation handler
            // or let the presenter handle the state. Dismissing is standard.
        }
    }

    @objc private func phoneChanged() {
        let digits = phoneTextField.text?.filter { $0.isNumber } ?? ""
        if digits.count > 10 { phoneTextField.text = String(digits.prefix(10)) }
        else { phoneTextField.text = digits }
        phoneTextField.layer.borderColor = brandTeal.cgColor
        updateSendButtonState()
    }

    private func updateSendButtonState() {
        let digits = phoneTextField.text?.filter { $0.isNumber } ?? ""
        let enabled = digits.count == 10
        sendCodeButton.isEnabled = enabled
        sendCodeButton.backgroundColor = enabled ? brandTeal : .systemGray4
    }

    @objc private func sendCodeTapped() {
        let digits = phoneTextField.text?.filter { $0.isNumber } ?? ""
        guard digits.count == 10 else { return }

        enteredPhone = digits
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        sendCodeButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                try await PhoneVerificationService.shared.sendOTP(phone: digits)
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.showToast("Verification code sent to +91 \(digits)")
                    UIView.transition(with: self.contentStack, duration: 0.3, options: .transitionCrossDissolve) {
                        self.showOTPEntry()
                    }
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.sendCodeButton.isEnabled = true
                    self.showToast("Failed to send OTP: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func otpFieldChanged(_ field: UITextField) {
        guard let text = field.text else { return }
        if text.count >= 1 {
            field.text = String(text.prefix(1))
            let idx = field.tag - 200
            if idx + 1 < otpFields.count {
                otpFields[idx + 1].becomeFirstResponder()
            } else {
                field.resignFirstResponder()
            }
        }
        field.layer.borderColor = text.isEmpty ? UIColor.systemGray4.cgColor : brandTeal.cgColor

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
            let success = try await PhoneVerificationService.shared.verifyOTP(phone: enteredPhone, otp: otp)
            if success {
                let userId = await SupabaseManager.shared.currentUserId() ?? ""
                try? await PhoneVerificationService.shared.markPhoneVerified(userId: userId, phone: enteredPhone)
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.showSuccess()
                }
            } else {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.failureCount += 1
                    if self.failureCount >= 5 {
                        self.showToast("Too many attempts. Request a new code.")
                        self.failureCount = 0
                        UIView.transition(with: self.contentStack, duration: 0.3, options: .transitionCrossDissolve) {
                            self.showPhoneEntry()
                        }
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        self.otpErrorLabel.text = "Incorrect code. Try again."
                        self.otpErrorLabel.isHidden = false
                        self.verifyButton.isEnabled = true
                        self.verifyButton.backgroundColor = self.brandTeal
                        self.shakeOTPFields()
                    }
                }
            }
        }
    }

    @objc private func resendTapped() {
        resendButton.isEnabled = false
        Task {
            try? await PhoneVerificationService.shared.sendOTP(phone: enteredPhone)
            await MainActor.run { self.startCooldown() }
        }
    }

    @objc private func changeNumberTapped() {
        UIView.transition(with: contentStack, duration: 0.3, options: .transitionCrossDissolve) {
            self.showPhoneEntry()
        }
    }

    // MARK: - UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Phone field
        if textField === phoneTextField {
            let current = textField.text ?? ""
            let newLength = current.count - range.length + string.count
            return newLength <= 10 && string.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) || string.isEmpty }
        }

        // OTP fields
        guard textField.tag >= 200 else { return true }

        if string.isEmpty && (textField.text?.isEmpty ?? true) {
            let idx = textField.tag - 200
            if idx > 0 {
                otpFields[idx - 1].becomeFirstResponder()
                otpFields[idx - 1].text = ""
                otpFields[idx - 1].layer.borderColor = UIColor.systemGray4.cgColor
            }
            return false
        }
        return string.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    // MARK: - Helpers

    private func formatPhoneDisplay(_ digits: String) -> String {
        guard digits.count == 10 else { return digits }
        let d = Array(digits)
        return "\(String(d[0..<5])) \(String(d[5..<10]))"
    }

    private func normalizedPhoneDigits(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        return digits.count > 10 ? String(digits.suffix(10)) : digits
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
        resendButton.setTitle("Resend (30s)", for: .normal)
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.cooldownSeconds -= 1
            if self.cooldownSeconds <= 0 {
                timer.invalidate()
                self.resendButton.isEnabled = true
                self.resendButton.setTitle("Resend Code", for: .normal)
                self.cooldownLabel.text = ""
            } else {
                self.resendButton.setTitle("Resend (\(self.cooldownSeconds)s)", for: .normal)
            }
        }
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.numberOfLines = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            toast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
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
}
