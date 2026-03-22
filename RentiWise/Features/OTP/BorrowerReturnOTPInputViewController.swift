//
//  BorrowerReturnOTPInputViewController.swift
//  RentiWise
//
//  Shown to the borrower when they need to verify item return.
//  Provides 4 OTP input boxes; calls `verify-return-otp` Edge Function.
//

import UIKit
import Supabase

final class BorrowerReturnOTPInputViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Inputs
    var requestId: String = ""
    var onVerified: (() -> Void)?

    // MARK: - UI
    private let titleLabel = UILabel()
    private let otpFields: [UITextField] = (0..<4).map { _ in UITextField() }
    private let confirmButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    private var attemptCount = 0
    private let maxAttempts = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verify Return"
        view.backgroundColor = .systemBackground
        setupUI()
        otpFields.first?.becomeFirstResponder()
    }

    // MARK: - UI Setup
    private func setupUI() {
        titleLabel.text = "Enter the 4-digit return code shown by the lender"
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

        confirmButton.setTitle("Confirm Return", for: .normal)
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
            let nextTag = field.tag + 1
            if nextTag < otpFields.count {
                otpFields[nextTag].becomeFirstResponder()
            } else {
                field.resignFirstResponder()
            }
        }
        field.layer.borderColor = text.isEmpty ? UIColor.systemGray4.cgColor : brandTeal.cgColor
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty && (textField.text?.isEmpty ?? true) {
            let prevTag = textField.tag - 1
            if prevTag >= 0 {
                otpFields[prevTag].becomeFirstResponder()
                otpFields[prevTag].text = ""
                otpFields[prevTag].layer.borderColor = UIColor.systemGray4.cgColor
            }
            return false
        }
        return string.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    // MARK: - Verify Return OTP
    @objc private func confirmTapped() {
        let otp = otpFields.map { $0.text ?? "" }.joined()
        guard otp.count == 4 else {
            showError("Please enter all 4 digits")
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
                let result: VerifyReturnOTPResponse = try await SupabaseManager.shared.client.functions
                    .invoke("verify-return-otp", options: .init(body: VerifyReturnOTPRequest(request_id: requestId, otp: otp)))

                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.confirmButton.isEnabled = true
                    if result.success {
                        self.showSuccess()
                    } else {
                        self.attemptCount += 1
                        self.showError(result.error ?? "Incorrect code. \(self.maxAttempts - self.attemptCount) attempts remaining.")
                        self.shakeInputFields()
                        if self.attemptCount >= self.maxAttempts {
                            self.disableInput()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.confirmButton.isEnabled = true
                    self.showError("Network error: \(error.localizedDescription)")
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

// MARK: - Models
private struct VerifyReturnOTPRequest: Encodable {
    let request_id: String
    let otp: String
}

private struct VerifyReturnOTPResponse: Decodable {
    let success: Bool
    let error: String?
}
