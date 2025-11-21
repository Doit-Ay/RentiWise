//
//  SignViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignViewController: UIViewController {

    // MARK: - Routing Context
    enum RoutingContext {
        case `default`
        case fromProfile
    }

    var routeContext: RoutingContext = .default

    // MARK: - Outlets
    @IBOutlet private weak var signInEmailText: UITextField!
    @IBOutlet private weak var signInPasswordText: UITextField!
    @IBOutlet private weak var signInButton: UIButton!

    // MARK: - Actions
    @IBAction func signUpSwitch(_ sender: UIButton) {
        let nibName: String = "SignUpViewController"
        let vc: SignUpViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = SignUpViewController(nibName: nibName, bundle: nil)
        } else {
            vc = SignUpViewController(service: SignUpService())
        }
        vc.title = ""
        vc.hidesBottomBarWhenPushed = true

        if let nav: UINavigationController = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            present(nav, animated: true)
        }
    }

    // MARK: - Dependencies
    private let validation = AuthValidationService()
    private lazy var signInServiceDefault: SignInServicing = SignInService()
    private var signInService: SignInServicing!

    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
    }

    // MARK: - Initializers
    init(service: SignInServicing) {
        super.init(nibName: nil, bundle: nil)
        self.signInService = service
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.signInService = SignInService()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.signInService = signInServiceDefault
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = ""
        hidesBottomBarWhenPushed = true

        signInEmailText?.keyboardType = UIKeyboardType.emailAddress
        signInEmailText?.autocapitalizationType = UITextAutocapitalizationType.none
        signInPasswordText?.isSecureTextEntry = true
    }

    // MARK: - Actions
    @IBAction private func GoogleSignIn(_ sender: UIButton) {}
    @IBAction private func AppleSignIn(_ sender: UIButton) {}

    @IBAction private func forgotPassword(_ sender: UIButton) {
        let vc = ForgotPasswordViewController(nibName: "ForgotPasswordViewController", bundle: nil)
        vc.title = ""
        vc.hidesBottomBarWhenPushed = true

        if let nav: UINavigationController = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            present(nav, animated: true)
        }
    }

    @IBAction private func signInProceed(_ sender: UIButton) {
        Task { await signIn() }
    }

    // MARK: - Sign In
    private func signIn() async {
        let email: String = signInEmailText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password: String = signInPasswordText.text ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            presentAlert(title: "Missing fields", message: "Please enter email and password.")
            return
        }
        guard validation.isValidEmail(email) else {
            presentAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }

        signInButton?.isEnabled = false
        defer { signInButton?.isEnabled = true }

        do {
            let credentials = SignInCredentials(email: email, password: password)
            let session: Session = try await signInService.signIn(credentials: credentials)

            try await signInService.upsertInitialProfile(
                userId: session.user.id.uuidString,
                email: email
            )

            routeAfterSuccessfulSignIn()
        } catch {
            presentAlert(title: "Sign In Failed", message: error.localizedDescription)
        }
    }

    private func routeAfterSuccessfulSignIn() {
        switch routeContext {
        case .fromProfile:
            // Use ProfileMainViewController's designated initializer which already loads its XIB
            let profileVC = ProfileMainViewController()
            profileVC.title = ""
            profileVC.hidesBottomBarWhenPushed = true

            if let nav: UINavigationController = navigationController {
                nav.setNavigationBarHidden(false, animated: false)
                nav.pushViewController(profileVC, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: profileVC)
                nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                present(nav, animated: true)
            }

        case .default:
            let storyboard = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
            let tabBarVC: UIViewController = storyboard.instantiateViewController(withIdentifier: Constants.navigationBarID)
            tabBarVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            present(tabBarVC, animated: true)
        }
    }

    // MARK: - Alerts
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        a.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
        present(a, animated: true)
    }
}
