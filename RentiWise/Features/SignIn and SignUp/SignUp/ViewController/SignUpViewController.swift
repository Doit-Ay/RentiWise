//
//  SignUpViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase
#if canImport(GoogleSignIn)
import GoogleSignIn
import GoogleSignInSwift
#endif

@MainActor
final class SignUpViewController: UIViewController {

    @IBOutlet private weak var signUpEmailText: UITextField!
    @IBOutlet private weak var signUpPasswordText: UITextField!
    @IBOutlet private weak var signUpFullNameText: UITextField!
    @IBOutlet private weak var signUpNumberText: UITextField!
    @IBOutlet private weak var signUpButton: UIButton!

    private let validation = AuthValidationService()
    private var signUpService: SignUpServicing
    private var isLoading: Bool = false

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

    @IBAction private func GoogleSignIn(_ sender: UIButton) {
#if canImport(GoogleSignIn)
        Task { await handleGoogleSignIn() }
#else
        presentAlert(title: "Unavailable", message: "Google Sign-In is not available in this build.")
#endif
    }
    @IBAction private func AppleSignIn(_ sender: UIButton) {}

    @IBAction private func signUpTapped(_ sender: UIButton) {
        Task { await signUp() }
    }

    @IBAction private func signinSwitch(_ sender: UIButton) {
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

                routeToProfileTab()
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

    // MARK: - Google Sign In
#if canImport(GoogleSignIn)
    @MainActor
    private func handleGoogleSignIn() async {
        isLoading = true
        defer { isLoading = false }

        guard let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String, !clientID.isEmpty else {
            presentAlert(title: "Configuration Error", message: "Google Client ID not configured.")
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            presentAlert(title: "Sign In Error", message: "Unable to find a presenting view controller.")
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                presentAlert(title: "Sign In Error", message: "Missing Google ID token.")
                return
            }
            let accessToken = result.user.accessToken.tokenString

            do {
                let signInService = SignInService()
                let session: Session = try await signInService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
                try await signInService.upsertInitialProfile(userId: session.user.id.uuidString, email: session.user.email ?? "")
                routeToProfileTab()
            } catch {
                presentAlert(title: "Google Sign In Failed", message: error.localizedDescription)
            }
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
            presentAlert(title: "Google Sign In Failed", message: error.localizedDescription)
        }
    }
#else
    @MainActor
    private func handleGoogleSignIn() async {
        presentAlert(title: "Unavailable", message: "Google Sign-In is not available in this build.")
    }
#endif

    // MARK: - Routing to Profile tab
    private func routeToProfileTab() {
        // Replace with your actual Profile tab index
        let profileTabIndex = 1

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let tab = window.rootViewController as? UITabBarController {
            guard profileTabIndex < (tab.viewControllers?.count ?? 0) else {
                pushProfileOnCurrentNav()
                return
            }

            tab.selectedIndex = profileTabIndex

            if let nav = tab.viewControllers?[profileTabIndex] as? UINavigationController {
                let profileVC = ProfileViewController()
                profileVC.title = ""
                profileVC.hidesBottomBarWhenPushed = false
                nav.setViewControllers([profileVC], animated: false)
            }

            if presentingViewController != nil {
                dismiss(animated: true)
            } else if let nav = navigationController {
                nav.popToRootViewController(animated: true)
            }
        } else {
            pushProfileOnCurrentNav()
        }
    }

    private func pushProfileOnCurrentNav() {
        let profileVC = ProfileViewController()
        profileVC.title = ""
        profileVC.hidesBottomBarWhenPushed = false
        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: false)
            nav.pushViewController(profileVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: profileVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

