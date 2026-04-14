//
//  ForgotPasswordViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

final class ForgotPasswordViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Brand color
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let emailLabel = UILabel()
    private let emailField = UITextField()
    private let continueButton = UIButton(type: .system)

    private let client = SupabaseManager.shared.client

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = ""
        buildUI()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Title
        titleLabel.text = "Reset Password"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Description
        descriptionLabel.text = "Enter the email address associated with your account. We'll send you a link to reset your password."
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)

        // Email
        emailLabel.text = "Email Address"
        emailLabel.font = .systemFont(ofSize: 17, weight: .medium)
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emailLabel)

        emailField.translatesAutoresizingMaskIntoConstraints = false
        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.font = .systemFont(ofSize: 14)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.layer.cornerRadius = 12
        emailField.layer.masksToBounds = true
        emailField.layer.borderWidth = 1
        emailField.layer.borderColor = brandTeal.cgColor
        emailField.delegate = self
        emailField.returnKeyType = .done
        contentView.addSubview(emailField)

        // Continue button
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.setTitle("Send Reset Link", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        continueButton.backgroundColor = brandTeal
        continueButton.layer.cornerRadius = 12
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        contentView.addSubview(continueButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            contentView.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor, constant: 30),

            emailLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            emailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            emailField.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 8),
            emailField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: emailField.trailingAnchor, constant: 20),
            emailField.heightAnchor.constraint(equalToConstant: 50),

            continueButton.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 30),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: continueButton.trailingAnchor, constant: 16),
            continueButton.heightAnchor.constraint(equalToConstant: 44),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        Task { await sendResetEmail() }
        return false
    }

    @objc private func continueTapped() {
        Task { await sendResetEmail() }
    }

    private func sendResetEmail() async {
        guard let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            presentAlert(title: "Error", message: "Please enter your email.")
            return
        }

        await MainActor.run { self.continueButton.isEnabled = false }

        do {
            try await client.auth.resetPasswordForEmail(email)
            await MainActor.run {
                self.presentAlert(title: "Email Sent", message: "A password reset link has been sent to \(email).")
                self.continueButton.isEnabled = true
            }
        } catch {
            await MainActor.run {
                self.presentAlert(title: "Error", message: error.localizedDescription)
                self.continueButton.isEnabled = true
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
