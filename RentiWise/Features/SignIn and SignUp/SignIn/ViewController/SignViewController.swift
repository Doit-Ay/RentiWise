//
//  SignViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {

    // MARK: - Routing Context
    enum RoutingContext {
        case `default`
        case fromProfile
    }

    var routeContext: RoutingContext = .default

    // MARK: - Brand color
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel = UILabel()
    private let emailLabel = UILabel()
    private let emailField = UITextField()
    private let passwordLabel = UILabel()
    private let passwordField = UITextField()
    private let forgotPasswordButton = UIButton(type: .system)
    private let signInButton = UIButton(type: .system)
    private let legalNoticeTextView = UITextView()
    private let switchLabel = UILabel()
    private let switchButton = UIButton(type: .system)

    // MARK: - State
    private var isLoading: Bool = false
    private let validation = AuthValidationService()
    private var signInService: SignInServicing
    private var activeField: UITextField?

    // MARK: - Initializers

    init(service: SignInServicing = SignInService()) {
        self.signInService = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.signInService = SignInService()
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = ""
        hidesBottomBarWhenPushed = true
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backToProfile)
        )

        buildUI()
        registerKeyboardObservers()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard presentedViewController == nil else { return }
        Task { await autoRouteIfAlreadySignedIn() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Build UI

    private func buildUI() {
        // Scroll view
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
        titleLabel.text = "Sign In"
        titleLabel.font = .systemFont(ofSize: 40, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Form stack
        let formStack = UIStackView()
        formStack.axis = .vertical
        formStack.spacing = 10
        formStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formStack)

        // Email
        configureFieldLabel(emailLabel, text: "Email Address")
        configureTextField(emailField, placeholder: "Email")
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.textContentType = .emailAddress
        emailField.returnKeyType = .next

        // Password
        configureFieldLabel(passwordLabel, text: "Password")
        configureTextField(passwordField, placeholder: "Password")
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .oneTimeCode
        passwordField.autocorrectionType = .no
        passwordField.spellCheckingType = .no
        passwordField.returnKeyType = .done

        for item in [emailLabel, emailField, passwordLabel, passwordField] {
            formStack.addArrangedSubview(item)
        }

        // Forgot password button
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.setTitleColor(brandTeal, for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 13)
        forgotPasswordButton.contentHorizontalAlignment = .trailing
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        contentView.addSubview(forgotPasswordButton)

        // Legal notice
        configureLegalNotice()
        contentView.addSubview(legalNoticeTextView)

        // Sign In button
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        signInButton.backgroundColor = brandTeal
        signInButton.layer.cornerRadius = 12
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        contentView.addSubview(signInButton)

        // Bottom switch row
        let bottomStack = UIStackView()
        bottomStack.axis = .horizontal
        bottomStack.spacing = 4
        bottomStack.alignment = .center
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomStack)

        switchLabel.text = "Don't have an account?"
        switchLabel.font = .systemFont(ofSize: 14)
        switchLabel.textColor = .label
        bottomStack.addArrangedSubview(switchLabel)

        switchButton.setTitle("Create account", for: .normal)
        switchButton.setTitleColor(brandTeal, for: .normal)
        switchButton.titleLabel?.font = .systemFont(ofSize: 13)
        switchButton.addTarget(self, action: #selector(signUpSwitch), for: .touchUpInside)
        bottomStack.addArrangedSubview(switchButton)

        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            formStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 70),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: formStack.trailingAnchor, constant: 20),

            forgotPasswordButton.topAnchor.constraint(equalTo: formStack.bottomAnchor, constant: 6),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: formStack.trailingAnchor),

            legalNoticeTextView.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 40),
            legalNoticeTextView.leadingAnchor.constraint(equalTo: formStack.leadingAnchor),
            legalNoticeTextView.trailingAnchor.constraint(equalTo: formStack.trailingAnchor),

            signInButton.topAnchor.constraint(equalTo: legalNoticeTextView.bottomAnchor, constant: 8),
            signInButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: signInButton.trailingAnchor, constant: 16),
            signInButton.heightAnchor.constraint(equalToConstant: 44),

            bottomStack.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 24),
            bottomStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    // MARK: - Field Helpers

    private func configureFieldLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
    }

    private func configureTextField(_ field: UITextField, placeholder: String) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 14)
        field.layer.cornerRadius = 12
        field.layer.masksToBounds = true
        field.layer.borderWidth = 1
        field.layer.borderColor = brandTeal.cgColor
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }

    // MARK: - Legal Notice

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
            .foregroundColor: brandTeal,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        legalNoticeTextView.attributedText = makeLegalNoticeText(prefix: "By continuing, you agree to our ")
        legalNoticeTextView.accessibilityIdentifier = "sign_in_legal_notice"
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

    // MARK: - Keyboard Handling

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let kbFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }

        let kbHeight = kbFrame.height
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: kbHeight, right: 0)

        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = insets
            self.scrollView.scrollIndicatorInsets = insets
        }

        if let active = activeField {
            let fieldRect = active.convert(active.bounds, to: scrollView)
            scrollView.scrollRectToVisible(fieldRect.insetBy(dx: 0, dy: -60), animated: true)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            let fieldRect = textField.convert(textField.bounds, to: self.scrollView)
            self.scrollView.scrollRectToVisible(fieldRect.insetBy(dx: 0, dy: -60), animated: true)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        activeField = nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            Task { await signIn() }
        }
        return false
    }

    // MARK: - Actions

    @objc private func backToProfile() {
        routeToProfileTab()
    }

    @objc private func forgotPasswordTapped() {
        let vc = ForgotPasswordViewController()
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

    @objc private func signInTapped() {
        Task { await signIn() }
    }

    @objc private func signUpSwitch() {
        let vc = SignUpViewController()
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

    // MARK: - Sign In Logic

    private func signIn() async {
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            presentAlert(title: "Missing fields", message: "Please enter email and password.")
            return
        }
        guard validation.isValidEmail(email) else {
            presentAlert(title: "Invalid Email", message: "Please enter a valid email address (e.g. user@example.com).")
            return
        }

        signInButton.isEnabled = false
        defer { signInButton.isEnabled = true }

        do {
            let credentials = SignInCredentials(email: email, password: password)
            let session: Session = try await signInService.signIn(credentials: credentials)

            try await signInService.upsertInitialProfile(
                userId: session.user.id.uuidString,
                email: email,
                fullName: session.user.userMetadata["full_name"]?.stringValue
            )
            AuthSessionStateStore.markSignedIn(provider: .password)
            await DeviceSessionManager.registerDeviceSession(userId: session.user.id.uuidString)

            // Sanity-check the session is live
            _ = try await SupabaseManager.shared.client.auth.session

            await MainActor.run { self.routeToProfileTab() }
        } catch {
            presentAlert(title: "Sign In Failed", message: error.localizedDescription)
        }
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
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
