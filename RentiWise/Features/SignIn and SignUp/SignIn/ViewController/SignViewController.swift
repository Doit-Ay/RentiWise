//
//  SignViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(GoogleSignInSwift)
import GoogleSignInSwift
#endif

@MainActor
final class SignViewController: UIViewController {

    private var isLoading: Bool = false

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

    // MARK: - Dependencies
    private let validation = AuthValidationService()
    private lazy var signInServiceDefault: SignInServicing = SignInService()
    private var signInService: SignInServicing!

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

        // Back to Profile button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backToProfile)
        )

        signInEmailText?.keyboardType = UIKeyboardType.emailAddress
        signInEmailText?.autocapitalizationType = UITextAutocapitalizationType.none
        signInPasswordText?.isSecureTextEntry = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await autoRouteIfAlreadySignedIn() }
    }

    // MARK: - Actions
    @IBAction private func GoogleSignIn(_ sender: UIButton) {
#if canImport(GoogleSignIn)
        Task { await handleGoogleSignIn() }
#else
        presentAlert(title: "Unavailable", message: "Google Sign-In isn't available in this build. Add the GoogleSignIn package to enable it.")
#endif
    }
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

    // NEW: IBAction for “Sign Up” button at the bottom
    // Connect your button’s Touch Up Inside to this action (signUpSwitch:)
    @IBAction private func signUpSwitch(_ sender: UIButton) {
        let nibName = "SignUpViewController"
        let vc: SignUpViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = SignUpViewController(nibName: nibName, bundle: nil)
        } else {
            vc = SignUpViewController(service: SignUpService())
        }
        vc.title = "Sign Up"
        vc.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    // MARK: - Back to Profile
    @objc private func backToProfile() {
        routeToProfileTab()
    }

    // MARK: - Sign In (email/password)
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

            // Sanity-check the session is live
            _ = try await SupabaseManager.shared.client.auth.session

            // Check if phone is verified; if not, show OTP screen
            await presentPhoneOTPIfNeeded()
        } catch {
            presentAlert(title: "Sign In Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Google Sign In (native token exchange)
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

        do {
            // Present from self to avoid nil presenter issues
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: self)

            guard let idToken = result.user.idToken?.tokenString else {
                presentAlert(title: "Sign In Error", message: "Missing Google ID token.")
                return
            }
            let accessToken = result.user.accessToken.tokenString

            let session = try await signInService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            try await signInService.upsertInitialProfile(userId: session.user.id.uuidString, email: session.user.email ?? "")

            // Sanity-check the session is live
            _ = try await SupabaseManager.shared.client.auth.session

            // Check if phone is verified; if not, show OTP screen
            await presentPhoneOTPIfNeeded()
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
            presentAlert(title: "Google Sign In Failed", message: error.localizedDescription)
        }
    }
#endif

    // MARK: - Phone OTP

    /// Checks if the user's phone is verified, and presents OTP screen if not.
    private func presentPhoneOTPIfNeeded() async {
        let service = ProfileService()
        do {
            let profile = try await service.fetchCurrentUserProfile()
            if profile.phoneVerified {
                routeToProfileTab()
            } else {
                presentPhoneOTP(prefillPhone: profile.phone)
            }
        } catch {
            // If we can't determine, just go to profile
            routeToProfileTab()
        }
    }

    private func presentPhoneOTP(prefillPhone: String) {
        let otpVC = PhoneOTPViewController()
        otpVC.prefillPhone = prefillPhone
        otpVC.onComplete = { [weak self] _ in
            // Whether verified or skipped, go to profile
            self?.dismiss(animated: true) {
                self?.routeToProfileTab()
            }
        }
        let nav = UINavigationController(rootViewController: otpVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Auto-route if already authenticated
    private func autoRouteIfAlreadySignedIn() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            _ = session.user
            await MainActor.run { self.routeToProfileTab() }
        } catch {
            // No session; stay on sign-in
        }
    }
    
    // MARK: - Routing to Profile tab
    private func routeToProfileTab() {
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

    // MARK: - Alerts
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        a.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
        present(a, animated: true)
    }
}

