//
//  AddItemDetailViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.

import UIKit

class AddItemDetailViewController: UIViewController {

    // Carry the draft from the first screen
    var draft: AddItemDraft = AddItemDraft()

    // MARK: - Outlets / Actions from IB

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
        draft.category = (selectACategory.text == "Select a category") ? "" : (selectACategory.text ?? "")
        draft.condition = (selectCondition.text == "Select condition") ? "" : (selectCondition.text ?? "")
        draft.description = descriptionTextView.text ?? ""

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

        return nil
    }

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

        // Prefill from draft if editing
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

        if !draft.description.isEmpty {
            descriptionTextView.text = draft.description
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


