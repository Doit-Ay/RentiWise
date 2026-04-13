//
//  SignUpViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignUpViewController: UIViewController, UITextViewDelegate {

    @IBOutlet private weak var authFormStackView: UIStackView!
    @IBOutlet private weak var signUpEmailText: UITextField!
    @IBOutlet private weak var signUpPasswordText: UITextField!
    @IBOutlet private weak var signUpConfirmPasswordText: UITextField!
    @IBOutlet private weak var signUpFullNameText: UITextField!
    @IBOutlet private weak var signUpNumberText: UITextField!
    @IBOutlet private weak var signUpButton: UIButton!
    @IBOutlet private weak var socialAuthStackView: UIStackView!

    private let validation = AuthValidationService()
    private var signUpService: SignUpServicing
    private var isLoading: Bool = false
    private var hasAcceptedAccountLegalConsent = false
    private let legalNoticeTextView = UITextView()

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
        title = ""
        signUpEmailText?.keyboardType = .emailAddress
        signUpEmailText?.autocapitalizationType = .none
        signUpPasswordText?.isSecureTextEntry = true
        signUpPasswordText?.textContentType = .oneTimeCode
        signUpPasswordText?.autocorrectionType = .no
        signUpPasswordText?.spellCheckingType = .no

        signUpConfirmPasswordText?.isSecureTextEntry = true
        signUpConfirmPasswordText?.textContentType = .oneTimeCode
        signUpConfirmPasswordText?.autocorrectionType = .no
        signUpConfirmPasswordText?.spellCheckingType = .no

        signUpFullNameText?.autocapitalizationType = .words
        signUpFullNameText?.autocorrectionType = .no
        
        signUpNumberText?.keyboardType = .phonePad

        // Back to Profile button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backToProfile)
        )

        // Hide social auth (Google) — only manual sign-up is supported
        socialAuthStackView?.isHidden = true

        configureLegalNotice()
    }

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

    // Legacy IBAction kept so XIB connection doesn't crash; does nothing
    @IBAction private func GoogleSignIn(_ sender: UIButton) {
        // Google Sign-In removed — no-op
    }

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
        vc.title = ""
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
        guard await ensureAccountLegalConsentIfNeeded(anchor: signUpButton) else { return }

        let email = signUpEmailText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = signUpPasswordText.text ?? ""
        let confirmPassword = signUpConfirmPasswordText.text ?? ""
        let fullName = signUpFullNameText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phone = signUpNumberText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty, !fullName.isEmpty else {
            presentAlert(title: "Missing fields", message: "Please fill in all the required fields.")
            return
        }
        guard password == confirmPassword else {
            presentAlert(title: "Passwords do not match", message: "Your password and confirm password must be the same.")
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
                AuthSessionStateStore.markSignedIn(provider: .password)
                await DeviceSessionManager.registerDeviceSession(userId: session.user.id.uuidString)

                // Sanity-check the session is live
                _ = try await SupabaseManager.shared.client.auth.session

                await MainActor.run { self.routeToProfileTab() }
            } else {
                presentAlert(
                    title: "Confirm your email",
                    message: "We've sent a confirmation link to \(email). Please confirm your email, then sign in to complete profile setup."
                )
            }
        } catch {
            presentAlert(title: "Sign Up Failed", message: error.localizedDescription)
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
        legalNoticeTextView.attributedText = makeLegalNoticeText(prefix: "By signing up, you agree to our ")
        legalNoticeTextView.accessibilityIdentifier = "sign_up_legal_notice"

        view.addSubview(legalNoticeTextView)
        NSLayoutConstraint.activate([
            legalNoticeTextView.leadingAnchor.constraint(equalTo: authFormStackView.leadingAnchor),
            legalNoticeTextView.trailingAnchor.constraint(equalTo: authFormStackView.trailingAnchor),
            legalNoticeTextView.topAnchor.constraint(greaterThanOrEqualTo: authFormStackView.bottomAnchor, constant: 4),
            legalNoticeTextView.bottomAnchor.constraint(equalTo: signUpButton.topAnchor, constant: -4)
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

    private func ensureAccountLegalConsentIfNeeded(anchor: UIView?) async -> Bool {
        if hasAcceptedAccountLegalConsent { return true }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Before Creating Your Account",
                message: "Please review and agree to the Terms of Service and Privacy Policy before continuing.",
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: "Review Terms of Service", style: .default) { [weak self] _ in
                self?.openLegalDocument(.termsOfService)
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: "Review Privacy Policy", style: .default) { [weak self] _ in
                self?.openLegalDocument(.privacyPolicy)
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: "Agree & Continue", style: .default) { [weak self] _ in
                self?.hasAcceptedAccountLegalConsent = true
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            if let popover = alert.popoverPresentationController {
                popover.sourceView = anchor ?? self.view
                popover.sourceRect = anchor?.bounds ?? self.view.bounds
            }
            present(alert, animated: true)
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

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
