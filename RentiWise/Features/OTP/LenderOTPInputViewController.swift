//
//  LenderOTPInputViewController.swift
//  RentiWise
//
//  Shown to the lender when they tap "Verify Borrower" on an accepted request.
//  Verifies the request-backed 6-digit pickup OTP shown by the borrower.
//

import UIKit
final class LenderOTPInputViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Inputs (set before push)
    var requestId: String = ""
    var onVerified: (() -> Void)?

    // MARK: - UI
    private let titleLabel = UILabel()
    private let otpFields: [UITextField] = (0..<6).map { _ in UITextField() }
    private let confirmButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    private var attemptCount = 0
    private let maxAttempts = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verify Pickup"
        view.backgroundColor = .systemBackground
        setupUI()
        otpFields.first?.becomeFirstResponder()
    }

    // MARK: - UI Setup
    private func setupUI() {
        titleLabel.text = "Enter the 6-digit code shown by the borrower"
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let otpStack = UIStackView(arrangedSubviews: otpFields)
        otpStack.axis = .horizontal
        otpStack.spacing = 12
        otpStack.distribution = .fillEqually
        otpStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, field) in otpFields.enumerated() {
            field.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
            field.textAlignment = .center
            field.keyboardType = .numberPad
            field.delegate = self
            field.tag = i
            field.layer.cornerRadius = 12
            field.layer.borderWidth = 2
            field.layer.borderColor = UIColor.systemGray4.cgColor
            field.backgroundColor = .secondarySystemBackground
            field.translatesAutoresizingMaskIntoConstraints = false
            field.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
            NSLayoutConstraint.activate([
                field.heightAnchor.constraint(equalToConstant: 60),
            ])
        }

        confirmButton.setTitle("Confirm Handoff", for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        confirmButton.backgroundColor = brandTeal
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 14
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        errorLabel.font = .systemFont(ofSize: 14, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, otpStack, errorLabel, confirmButton, spinner])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Text Field Handling
    @objc private func textFieldChanged(_ field: UITextField) {
        guard let text = field.text else { return }
        if text.count >= 1 {
            field.text = String(text.prefix(1))
            // Auto-advance to next field
            let nextTag = field.tag + 1
            if nextTag < otpFields.count {
                otpFields[nextTag].becomeFirstResponder()
            } else {
                field.resignFirstResponder()
            }
        }
        // Update border color
        field.layer.borderColor = text.isEmpty ? UIColor.systemGray4.cgColor : brandTeal.cgColor
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Handle backspace: move to previous field
        if string.isEmpty && (textField.text?.isEmpty ?? true) {
            let prevTag = textField.tag - 1
            if prevTag >= 0 {
                otpFields[prevTag].becomeFirstResponder()
                otpFields[prevTag].text = ""
                otpFields[prevTag].layer.borderColor = UIColor.systemGray4.cgColor
            }
            return false
        }

        // Only allow digits
        let allowedChars = CharacterSet.decimalDigits
        return string.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }

    // MARK: - Verify OTP
    @objc private func confirmTapped() {
        let otp = otpFields.map { $0.text ?? "" }.joined()
        guard otp.count == 6 else {
            showError("Please enter all 6 digits")
            shakeInputFields()
            return
        }

        guard attemptCount < maxAttempts else {
            showError("Too many failed attempts. Contact support.")
            return
        }

        confirmButton.isEnabled = false
        spinner.startAnimating()
        errorLabel.isHidden = true

        Task {
            do {
                try await PickupOTPService.shared.verifyPickupCode(requestId: requestId, otp: otp)

                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.confirmButton.isEnabled = true
                    self.showSuccess()
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.confirmButton.isEnabled = true
                    let message = error.localizedDescription
                    let countsAsFailedAttempt = message.localizedCaseInsensitiveContains("doesn't match")

                    self.showError(message)
                    if countsAsFailedAttempt {
                        self.attemptCount += 1
                        self.shakeInputFields()
                        if self.attemptCount >= self.maxAttempts {
                            self.disableInput()
                        }
                    }
                }
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    private func shakeInputFields() {
        for field in otpFields {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shake.values = [0, -10, 10, -8, 8, -4, 4, 0]
            shake.duration = 0.4
            field.layer.add(shake, forKey: "shake")
            field.layer.borderColor = UIColor.systemRed.cgColor
        }
    }

    private func disableInput() {
        otpFields.forEach { $0.isEnabled = false }
        confirmButton.isEnabled = false
        showError("Too many failed attempts. Please contact support.")
    }

    private func showSuccess() {
        // Checkmark animation
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmark.tintColor = .systemGreen
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.alpha = 0
        checkmark.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        view.addSubview(checkmark)
        NSLayoutConstraint.activate([
            checkmark.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 80),
            checkmark.heightAnchor.constraint(equalToConstant: 80),
        ])

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            checkmark.alpha = 1
            checkmark.transform = .identity
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onVerified?()
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}
