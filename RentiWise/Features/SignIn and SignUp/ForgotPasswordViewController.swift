//
//  ForgotPasswordViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

final class ForgotPasswordViewController: UIViewController {

    @IBOutlet private weak var forgotPasswordEmailText: UITextField!
    @IBOutlet private weak var continueButton: UIButton!

    private let client = SupabaseManager.shared.client

    override func viewDidLoad() {
        super.viewDidLoad()
        forgotPasswordEmailText?.keyboardType = .emailAddress
        forgotPasswordEmailText?.autocapitalizationType = .none
    }

    @IBAction private func forgotPasswordContinue(_ sender: UIButton) {
        Task { await sendResetEmail() }
    }

    private func sendResetEmail() async {
        guard let email = forgotPasswordEmailText.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            presentAlert(title: "Error", message: "Please enter your email.")
            return
        }

        await MainActor.run { self.continueButton?.isEnabled = false }

        do {
            // Optional: configure redirect URL if you handle password reset in-app
            // try await client.auth.resetPasswordForEmail(email, redirectTo: URL(string: "yourapp://password-reset")!)

            try await client.auth.resetPasswordForEmail(email)
            await MainActor.run {
                self.presentAlert(title: "Email Sent", message: "A password reset link has been sent to \(email).")
                self.continueButton?.isEnabled = true
            }
        } catch {
            await MainActor.run {
                self.presentAlert(title: "Error", message: error.localizedDescription)
                self.continueButton?.isEnabled = true
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
