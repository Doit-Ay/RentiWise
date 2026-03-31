//
//  SignViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignViewController: UIViewController, UITextViewDelegate {

    private var isLoading: Bool = false

    // MARK: - Routing Context
    enum RoutingContext {
        case `default`
        case fromProfile
    }

    var routeContext: RoutingContext = .default

    // MARK: - Outlets
    @IBOutlet private weak var authFormStackView: UIStackView!
    @IBOutlet private weak var signInEmailText: UITextField!
    @IBOutlet private weak var signInPasswordText: UITextField!
    @IBOutlet private weak var signInButton: UIButton!
    @IBOutlet private weak var socialAuthStackView: UIStackView!

    // MARK: - Dependencies
    private let validation = AuthValidationService()
    private lazy var signInServiceDefault: SignInServicing = SignInService()
    private var signInService: SignInServicing!
    private let legalNoticeTextView = UITextView()

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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Legal",
            style: .plain,
            target: self,
            action: #selector(showLegalMenu)
        )

        signInEmailText?.keyboardType = UIKeyboardType.emailAddress
        signInEmailText?.autocapitalizationType = UITextAutocapitalizationType.none
        signInPasswordText?.isSecureTextEntry = true
        configureSocialAuthButtons()
        configureLegalNotice()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard presentedViewController == nil else { return }
        Task { await autoRouteIfAlreadySignedIn() }
    }

    // MARK: - Actions
    @IBAction private func GoogleSignIn(_ sender: UIButton) {
        // Google Sign-In removed for Guideline 4.8 compliance (requires SIWA).
        // Email/password authentication remains available.
    }
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

    @objc private func showLegalMenu() {
        let alert = UIAlertController(title: "Legal", message: "Review our terms and privacy details before continuing.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Terms of Service", style: .default) { [weak self] _ in
            self?.openLegalDocument(.termsOfService)
        })
        alert.addAction(UIAlertAction(title: "Privacy Policy", style: .default) { [weak self] _ in
            self?.openLegalDocument(.privacyPolicy)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
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
                email: email,
                fullName: session.user.userMetadata["full_name"]?.stringValue
            )
            AuthSessionStateStore.markSignedIn(provider: .password)

            // Sanity-check the session is live
            _ = try await SupabaseManager.shared.client.auth.session

            // Check if phone is verified; if not, show OTP screen
            await presentPhoneOTPIfNeeded()
        } catch {
            presentAlert(title: "Sign In Failed", message: error.localizedDescription)
        }
    }



    private func configureLegalNotice() {
        legalNoticeTextView.translatesAutoresizingMaskIntoConstraints = false
        legalNoticeTextView.backgroundColor = .clear
        legalNoticeTextView.isEditable = false
        legalNoticeTextView.isScrollEnabled = false
        legalNoticeTextView.delegate = self
        legalNoticeTextView.textAlignment = .center
        legalNoticeTextView.adjustsFontForContentSizeCategory = true
        legalNoticeTextView.textContainerInset = .zero
        legalNoticeTextView.textContainer.lineFragmentPadding = 0
        legalNoticeTextView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        legalNoticeTextView.attributedText = makeLegalNoticeText(prefix: "By continuing, you agree to our ")
        legalNoticeTextView.accessibilityIdentifier = "sign_in_legal_notice"

        view.addSubview(legalNoticeTextView)
        NSLayoutConstraint.activate([
            legalNoticeTextView.leadingAnchor.constraint(equalTo: authFormStackView.leadingAnchor),
            legalNoticeTextView.trailingAnchor.constraint(equalTo: authFormStackView.trailingAnchor),
            legalNoticeTextView.topAnchor.constraint(greaterThanOrEqualTo: authFormStackView.bottomAnchor, constant: 8),
            legalNoticeTextView.bottomAnchor.constraint(equalTo: signInButton.topAnchor, constant: -8)
        ])
    }

    private func makeLegalNoticeText(prefix: String) -> NSAttributedString {
        let text = prefix + "Terms of Service and Privacy Policy."
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        let nsText = text as NSString
        attributed.addAttribute(.link, value: "rentiwise://legal/terms", range: nsText.range(of: "Terms of Service"))
        attributed.addAttribute(.link, value: "rentiwise://legal/privacy", range: nsText.range(of: "Privacy Policy"))
        return attributed
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith url: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        switch url.absoluteString {
        case "rentiwise://legal/terms":
            openLegalDocument(.termsOfService)
        case "rentiwise://legal/privacy":
            openLegalDocument(.privacyPolicy)
        default:
            return true
        }
        return false
    }

    private func configureSocialAuthButtons() {
        // Social auth buttons removed for Guideline 4.8 compliance.
        // Google Sign-In requires Sign in with Apple to also be offered.
        // Hide the stack view since no social buttons are available.
        socialAuthStackView?.isHidden = true
    }



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

    private func openLegalDocument(_ document: LegalDocument) {
        let vc = LegalDocumentViewController(document: document)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Alerts
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        a.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
        present(a, animated: true)
    }
}
