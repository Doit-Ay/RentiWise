//
//  SignUpViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignUpViewController: UIViewController {

    @IBOutlet private weak var signUpEmailText: UITextField!
    @IBOutlet private weak var signUpPasswordText: UITextField!
    @IBOutlet private weak var signUpFullNameText: UITextField!
    @IBOutlet private weak var signUpNumberText: UITextField!
    @IBOutlet private weak var signUpButton: UIButton!

    private let validation = AuthValidationService()
    private var signUpService: SignUpServicing

    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
        static let authStoryboard = "Main"
        static let signInID = "SignViewController"
    }

    // Designated DI initializer
    init(service: SignUpServicing) {
        self.signUpService = service
        super.init(nibName: nil, bundle: nil)
    }

    // Proper override for XIB-based loading via nibName:bundle:
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.signUpService = SignUpService()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    // XIB/Storyboard initializer
    required init?(coder: NSCoder) {
        self.signUpService = SignUpService()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        signUpEmailText?.keyboardType = .emailAddress
        signUpEmailText?.autocapitalizationType = .none
        signUpPasswordText?.isSecureTextEntry = true
        signUpNumberText?.keyboardType = .phonePad
    }

    @IBAction private func GoogleSignIn(_ sender: UIButton) {}
    @IBAction private func AppleSignIn(_ sender: UIButton) {}

    @IBAction private func signUpTapped(_ sender: UIButton) {
        Task { await signUp() }
    }

    @IBAction private func signinSwitch(_ sender: UIButton) {
        // If you want XIB for SignViewController as well, load via nibName:
        let nibName = "SignViewController"
        let vc: SignViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = SignViewController(nibName: nibName, bundle: nil)
        } else {
            vc = SignViewController(service: SignInService())
        }
        vc.title = "Sign In"
        vc.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    private func signUp() async {
        let email = signUpEmailText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = signUpPasswordText.text ?? ""
        let fullName = signUpFullNameText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phone = signUpNumberText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !email.isEmpty, !password.isEmpty, !fullName.isEmpty else {
            presentAlert(title: "Missing fields", message: "Please enter name, email and password.")
            return
        }
        guard validation.isValidEmail(email) else {
            presentAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }
        guard validation.isValidPassword(password) else {
            presentAlert(title: "Weak Password", message: "Password should be at least 6 characters.")
            return
        }

        signUpButton?.isEnabled = false
        defer { signUpButton?.isEnabled = true }

        do {
            let credentials = SignUpCredentials(email: email, password: password)
            let profile = SignUpUserProfile(fullName: fullName, phone: phone)

            let result = try await signUpService.signUp(credentials: credentials)

            if let session = result.session {
                try await signUpService.upsertUserProfile(
                    userId: session.user.id.uuidString,
                    email: email,
                    profile: profile
                )

                let storyboard = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
                let tabBarVC: UIViewController = storyboard.instantiateViewController(withIdentifier: Constants.navigationBarID)
                tabBarVC.modalPresentationStyle = .fullScreen
                present(tabBarVC, animated: true)
            } else {
                presentAlert(
                    title: "Confirm your email",
                    message: "We’ve sent a confirmation link to \(email). Please confirm your email, then sign in to complete profile setup."
                )
            }
        } catch {
            presentAlert(title: "Sign Up Failed", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
