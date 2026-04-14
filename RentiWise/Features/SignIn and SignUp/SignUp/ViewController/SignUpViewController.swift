//
//  SignUpViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit
import Supabase

@MainActor
final class SignUpViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {

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
    private let confirmPasswordLabel = UILabel()
    private let confirmPasswordField = UITextField()
    private let fullNameLabel = UILabel()
    private let fullNameField = UITextField()
    private let phoneLabel = UILabel()
    private let phoneField = UITextField()
    private let signUpButton = UIButton(type: .system)
    private let legalNoticeTextView = UITextView()
    private let switchLabel = UILabel()
    private let switchButton = UIButton(type: .system)

    // MARK: - State
    private let validation = AuthValidationService()
    private var signUpService: SignUpServicing
    private var isLoading: Bool = false
    private var hasAcceptedAccountLegalConsent = false
    private var activeField: UITextField?

    // MARK: - Initializers

    init(service: SignUpServicing = SignUpService()) {
        self.signUpService = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.signUpService = SignUpService()
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backToProfile)
        )

        buildUI()
        configureFields()
        registerKeyboardObservers()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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
        titleLabel.text = "Sign Up"
        titleLabel.font = .systemFont(ofSize: 40, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Form fields
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

        // Password
        configureFieldLabel(passwordLabel, text: "Password")
        configureTextField(passwordField, placeholder: "Password")
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .oneTimeCode
        passwordField.autocorrectionType = .no
        passwordField.spellCheckingType = .no

        // Confirm Password
        configureFieldLabel(confirmPasswordLabel, text: "Confirm Password")
        configureTextField(confirmPasswordField, placeholder: "Confirm Password")
        confirmPasswordField.isSecureTextEntry = true
        confirmPasswordField.textContentType = .oneTimeCode
        confirmPasswordField.autocorrectionType = .no
        confirmPasswordField.spellCheckingType = .no

        // Full Name
        configureFieldLabel(fullNameLabel, text: "Full Name")
        configureTextField(fullNameField, placeholder: "Full Name")
        fullNameField.autocapitalizationType = .words
        fullNameField.autocorrectionType = .no
        fullNameField.textContentType = .name

        // Phone Number
        configureFieldLabel(phoneLabel, text: "Phone Number")
        configureTextField(phoneField, placeholder: "10-digit mobile number")
        phoneField.keyboardType = .numberPad
        phoneField.textContentType = .telephoneNumber
        let prefixLabel = UILabel()
        prefixLabel.text = "  +91 "
        prefixLabel.font = phoneField.font ?? .systemFont(ofSize: 16)
        prefixLabel.textColor = .secondaryLabel
        prefixLabel.sizeToFit()
        phoneField.leftView = prefixLabel
        phoneField.leftViewMode = .always

        // Add to stack
        for item in [emailLabel, emailField,
                     passwordLabel, passwordField,
                     confirmPasswordLabel, confirmPasswordField,
                     fullNameLabel, fullNameField,
                     phoneLabel, phoneField] {
            formStack.addArrangedSubview(item)
        }

        // Legal notice
        configureLegalNotice()
        contentView.addSubview(legalNoticeTextView)

        // Sign Up button
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.setTitleColor(.white, for: .normal)
        signUpButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        signUpButton.backgroundColor = brandTeal
        signUpButton.layer.cornerRadius = 12
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        contentView.addSubview(signUpButton)

        // Bottom switch row
        let bottomStack = UIStackView()
        bottomStack.axis = .horizontal
        bottomStack.spacing = 4
        bottomStack.alignment = .center
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomStack)

        switchLabel.text = "Already have an account?"
        switchLabel.font = .systemFont(ofSize: 14)
        switchLabel.textColor = .label
        bottomStack.addArrangedSubview(switchLabel)

        switchButton.setTitle("Sign In", for: .normal)
        switchButton.setTitleColor(brandTeal, for: .normal)
        switchButton.titleLabel?.font = .systemFont(ofSize: 13)
        switchButton.addTarget(self, action: #selector(signinSwitch), for: .touchUpInside)
        bottomStack.addArrangedSubview(switchButton)

        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            formStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: formStack.trailingAnchor, constant: 20),

            legalNoticeTextView.topAnchor.constraint(equalTo: formStack.bottomAnchor, constant: 12),
            legalNoticeTextView.leadingAnchor.constraint(equalTo: formStack.leadingAnchor),
            legalNoticeTextView.trailingAnchor.constraint(equalTo: formStack.trailingAnchor),

            signUpButton.topAnchor.constraint(equalTo: legalNoticeTextView.bottomAnchor, constant: 8),
            signUpButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: signUpButton.trailingAnchor, constant: 16),
            signUpButton.heightAnchor.constraint(equalToConstant: 44),

            bottomStack.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 24),
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
        field.returnKeyType = .next
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }

    private func configureFields() {
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
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
        legalNoticeTextView.attributedText = makeLegalNoticeText(prefix: "By signing up, you agree to our ")
        legalNoticeTextView.accessibilityIdentifier = "sign_up_legal_notice"
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
        } else if textField === passwordField {
            confirmPasswordField.becomeFirstResponder()
        } else if textField === confirmPasswordField {
            fullNameField.becomeFirstResponder()
        } else if textField === fullNameField {
            phoneField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Phone field: allow only digits, max 10 chars
        if textField === phoneField {
            let allowedCharacters = CharacterSet.decimalDigits
            if !string.isEmpty && string.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
                return false
            }
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            return newLength <= 10
        }
        // Full name field: allow only letters and spaces
        if textField === fullNameField {
            let allowed = CharacterSet.letters.union(.whitespaces)
            if !string.isEmpty && string.unicodeScalars.contains(where: { !allowed.contains($0) }) {
                return false
            }
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            return newLength <= 50
        }
        return true
    }

    // MARK: - Actions

    @objc private func backToProfile() {
        routeToProfileTab()
    }

    @objc private func signUpTapped() {
        Task { await signUp() }
    }

    @objc private func signinSwitch() {
        let vc = SignViewController()
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

    // MARK: - Sign Up Logic

    private func signUp() async {
        guard await ensureAccountLegalConsentIfNeeded(anchor: signUpButton) else { return }

        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text ?? ""
        let confirmPassword = confirmPasswordField.text ?? ""
        let fullName = fullNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phoneRaw = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty, !fullName.isEmpty else {
            presentAlert(title: "Missing fields", message: "Please fill in all the required fields.")
            return
        }
        guard validation.isValidFullName(fullName) else {
            presentAlert(title: "Invalid Name", message: "Name must contain only letters and spaces (2–50 characters).")
            return
        }
        guard password == confirmPassword else {
            presentAlert(title: "Passwords do not match", message: "Your password and confirm password must be the same.")
            return
        }
        guard validation.isValidEmail(email) else {
            presentAlert(title: "Invalid Email", message: "Please enter a valid email address (e.g. user@example.com).")
            return
        }
        guard validation.isValidPassword(password) else {
            presentAlert(title: "Weak Password", message: "Password must be at least 6 characters with an uppercase letter, a lowercase letter, and a digit.")
            return
        }
        // Phone is optional but if provided must be valid
        let phone: String
        if !phoneRaw.isEmpty {
            guard validation.isValidPhone(phoneRaw) else {
                presentAlert(title: "Invalid Phone", message: "Please enter a valid 10-digit Indian mobile number.")
                return
            }
            phone = validation.e164Phone(phoneRaw)
        } else {
            phone = ""
        }

        signUpButton.isEnabled = false
        defer { signUpButton.isEnabled = true }

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
