//
//  AddItemDetailViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.

import UIKit

class AddItemDetailViewController: UIViewController {

    // Carry the draft from the first screen
    var draft: AddItemDraft = AddItemDraft()

    // MARK: - Scroll view for keyboard avoidance
    /// Wraps the main content so the screen scrolls when the keyboard appears.
    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // MARK: - Outlets / Actions from IB

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var descriptionHeadingLabel: UILabel!

    @IBAction func itemTitleTextField(_ sender: UITextField) {
        // Keep draft.title in sync if you wire this action from the title text field
        draft.title = sender.text ?? ""
    }

    @IBOutlet weak var categorySelection: UIStackView!
    @IBOutlet weak var selectACategory: UILabel!

    // Chevron button actions intentionally left empty (handled by native UIMenu on stack view)
    @IBAction func categoryChevronButton(_ sender: Any) {}

    @IBOutlet weak var conditionSelection: UIStackView!
    @IBOutlet weak var selectCondition: UILabel!

    // Chevron button actions intentionally left empty
    @IBAction func conditionChevronButton(_ sender: UIButton) {}

    @IBOutlet weak var descriptionTextView: UITextView!

    // Continue button → push AddItemPricingViewController from its XIB
    @IBAction func ContinueTapped(_ sender: UIButton) {
        // Update draft with chosen values from UI controls
        if let titleText = titleTextField?.text {
            draft.title = titleText
        }
        draft.category = (selectACategory.text == "Select a category") ? "" : (selectACategory.text ?? "")
        draft.condition = (selectCondition.text == "Select condition") ? "" : (selectCondition.text ?? "")
        
        let descText = descriptionTextView.text ?? ""
        draft.description = (descText == descriptionPlaceholder) ? "" : descText

        // Validate required fields before proceeding
        if let errorMessage = validateDraft() {
            presentAlert(title: "Missing Information", message: errorMessage)
            return
        }

        let vc = AddItemPricingViewController(nibName: "AddItemPricingViewController", bundle: nil)
        vc.title = "Add item"
        vc.hidesBottomBarWhenPushed = true
        vc.draft = draft

        guard let nav = navigationController else {
            assertionFailure("AddItemDetailViewController must be pushed inside a UINavigationController within the tab bar.")
            return
        }
        nav.pushViewController(vc, animated: true)
    }

    // MARK: - Validation

    // Returns an error message if something is missing; nil if valid.
    private func validateDraft() -> String? {
        // Require at least one image from the first screen
        if draft.images.isEmpty {
            return "Please add at least one photo."
        }

        // Title required
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "Please enter a title for your item."
        }

        // Category required
        let trimmedCategory = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCategory.isEmpty {
            return "Please select a category."
        }

        // Condition required
        let trimmedCondition = draft.condition.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCondition.isEmpty {
            return "Please select a condition."
        }

        // Description required (if you want it mandatory)
        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            return "Please add a short description."
        }
        
        if trimmedDescription.count > 180 {
            return "Description must be 180 characters or less."
        }

        return nil
    }

    // MARK: - Description Placeholder
    let descriptionPlaceholder = "e.g., A small, portable air conditioner..."

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if title?.isEmpty ?? true { title = "Add item" }
        view.backgroundColor = .systemBackground

        if let navBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
        }

        // ── Wrap all XIB content in a scroll view for keyboard avoidance ──
        wrapContentInScrollView()

        // Initialize the dynamic character count for the header label
        updateCharacterCount(for: draft.description)

        // Prefill from draft if editing
        if !draft.title.isEmpty {
            titleTextField?.text = draft.title
        }

        if !draft.category.isEmpty {
            selectACategory.text = draft.category
            selectACategory.textColor = .label
        } else if (selectACategory.text?.isEmpty ?? true) {
            selectACategory.text = "Select a category"
        }

        if !draft.condition.isEmpty {
            selectCondition.text = draft.condition
            selectCondition.textColor = .label
        } else if (selectCondition.text?.isEmpty ?? true) {
            selectCondition.text = "Select condition"
        }

        descriptionTextView.delegate = self
        if !draft.description.isEmpty {
            descriptionTextView.text = draft.description
            descriptionTextView.textColor = .label
        } else {
            descriptionTextView.text = descriptionPlaceholder
            descriptionTextView.textColor = .placeholderText
        }

        // Setup iOS native UIMenu for dropdowns
        setupNativeMenus()

        // Keyboard dismissal improvements:
        // 1) Tap anywhere to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        // Register keyboard observers
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Scroll View Wrapping

    /// Programmatically wraps all existing XIB subviews inside a UIScrollView
    /// so the content can scroll when the keyboard is visible.
    private func wrapContentInScrollView() {
        // Create scroll view
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive

        // Create a content container
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Collect existing subviews from the XIB root view
        let existingSubviews = view.subviews
        for sub in existingSubviews {
            sub.removeFromSuperview()
            container.addSubview(sub)
        }

        sv.addSubview(container)
        view.addSubview(sv)

        // Pin scroll view to safe area
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: safeArea.topAnchor),
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Pin container inside scroll view (defines scrollable area)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
            // Container width = scroll view width (no horizontal scrolling)
            container.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor)
        ])

        // Re-apply constraints for the existing subviews relative to the container
        // StepHeader (jzr-he-Y9k) – the first stack view
        // Card view (2aV-KQ-rZa) – the form card
        // Continue button (d6D-Kw-xkq)
        // We identify them by order: stepHeader, cardView, continueButton
        guard existingSubviews.count >= 3 else { return }
        let stepHeader = existingSubviews[0]
        let cardView = existingSubviews[1]
        let continueButton = existingSubviews[2]

        NSLayoutConstraint.activate([
            // Step header
            stepHeader.topAnchor.constraint(equalTo: container.topAnchor),
            stepHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stepHeader.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Card view
            cardView.topAnchor.constraint(equalTo: stepHeader.bottomAnchor, constant: 20),
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            // Continue button
            continueButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 20),
            continueButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            continueButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -30)
        ])

        self.scrollView = sv
        self.contentView = container
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let scrollView = scrollView,
              let info = notification.userInfo,
              let kbFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        let kbHeight = kbFrame.height
        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kbHeight, right: 0)

        UIView.animate(withDuration: duration) {
            scrollView.contentInset = contentInset
            scrollView.scrollIndicatorInsets = contentInset
        }

        // Scroll to the description text view if it is the first responder
        if descriptionTextView.isFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let rect = self.descriptionTextView.convert(self.descriptionTextView.bounds, to: scrollView)
                scrollView.scrollRectToVisible(rect, animated: true)
            }
        } else if titleTextField.isFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let rect = self.titleTextField.convert(self.titleTextField.bounds, to: scrollView)
                scrollView.scrollRectToVisible(rect, animated: true)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let scrollView = scrollView,
              let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        UIView.animate(withDuration: duration) {
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
        }
    }

    // MARK: - Native Dropdowns

    fileprivate enum DropdownKind {
        case category
        case condition

        var options: [String] {
            switch self {
            case .category:
                return ["Electronics", "Tools", "Events", "Fitness", "Hobbies", "Outdoor", "Custom"]
            case .condition:
                return ["New", "Good", "Poor"]
            }
        }
    }

    private func setupNativeMenus() {
        if let categoryStack = categorySelection {
            addNativeMenu(to: categoryStack, kind: .category)
        }
        if let conditionStack = conditionSelection {
            addNativeMenu(to: conditionStack, kind: .condition)
        }
    }

    private func addNativeMenu(to stack: UIStackView, kind: DropdownKind) {
        let menuButton = UIButton(type: .system)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        stack.addSubview(menuButton)
        stack.isUserInteractionEnabled = true
        
        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: stack.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: stack.bottomAnchor)
        ])
        
        let actions = kind.options.map { option in
            UIAction(title: option) { [weak self] _ in
                guard let self = self else { return }
                switch kind {
                case .category:
                    self.selectACategory.text = option
                    self.selectACategory.textColor = .label
                    self.draft.category = option
                case .condition:
                    self.selectCondition.text = option
                    self.selectCondition.textColor = .label
                    self.draft.condition = option
                }
            }
        }
        
        menuButton.menu = UIMenu(title: "", children: actions)
        menuButton.showsMenuAsPrimaryAction = true
    }

    private func addPlaceholderLabelIfNeeded() {
        let label = UILabel()
        label.text = "Item details go here"
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Handlers
    
    func updateCharacterCount(for text: String) {
        let actualText = (text == descriptionPlaceholder) ? "" : text
        let count = actualText.count
        
        let attributedString = NSMutableAttributedString(string: "Description ", attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: UIColor.label
        ])
        
        // Use red text color if the user has exceeded the 180 character limit
        let countColor: UIColor = count > 180 ? .systemRed : .secondaryLabel
        let subtitleString = NSAttributedString(string: "(\(count)/180 chars)", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: countColor
        ])
        attributedString.append(subtitleString)
        descriptionHeadingLabel?.attributedText = attributedString
    }

    // Dismiss keyboard utility
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Alerts

    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

extension AddItemDetailViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == descriptionPlaceholder {
            textView.text = ""
            textView.textColor = .label
        }
        // Scroll the description text view into view when it becomes active
        if let scrollView = scrollView {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let rect = textView.convert(textView.bounds, to: scrollView)
                scrollView.scrollRectToVisible(rect, animated: true)
            }
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = descriptionPlaceholder
            textView.textColor = .placeholderText
        }
    }
    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCount(for: textView.text)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Allow typing past 300 characters, we handle validation sequentially on continue
        return true
    }
}

