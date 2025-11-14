//
//  AddItemDetailViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

class AddItemDetailViewController: UIViewController {

    // MARK: - Outlets / Actions from IB

    @IBAction func itemTitleTextField(_ sender: UITextField) {}

    @IBOutlet weak var categorySelection: UIStackView!
    @IBOutlet weak var selectACategory: UILabel!

    // Chevron button → open inline dropdown
    @IBAction func categoryChevronButton(_ sender: Any) {
        showDropdown(for: .category, from: categorySelection)
    }

    @IBOutlet weak var conditionSelection: UIStackView!
    @IBOutlet weak var selectCondition: UILabel!

    // Chevron button → open inline dropdown
    @IBAction func conditionChevronButton(_ sender: UIButton) {
        showDropdown(for: .condition, from: conditionSelection)
    }

    @IBOutlet weak var descriptionTextView: UITextView!

    // Continue button → push AddItemPricingViewController from its XIB
    @IBAction func ContinueTapped(_ sender: UIButton) {
        let vc = AddItemPricingViewController(nibName: "AddItemPricingViewController", bundle: nil)
        vc.title = "Add item"
        vc.hidesBottomBarWhenPushed = true

        guard let nav = navigationController else {
            assertionFailure("AddItemDetailViewController must be pushed inside a UINavigationController within the tab bar.")
            return
        }
        nav.pushViewController(vc, animated: true)
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

        if (selectACategory.text?.isEmpty ?? true) { selectACategory.text = "Select a category" }
        if (selectCondition.text?.isEmpty ?? true) { selectCondition.text = "Select condition" }

        // Reset and add tap gestures so each row opens its own inline dropdown
        resetGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Gesture wiring

    private func resetGestures() {
        [categorySelection, conditionSelection].forEach { stack in
            stack?.gestureRecognizers?.forEach { stack?.removeGestureRecognizer($0) }
        }
        addTapToStack(categorySelection, action: #selector(handleCategoryRowTap))
        addTapToStack(conditionSelection, action: #selector(handleConditionRowTap))
    }

    // MARK: - Row tap handlers (inline dropdown)

    @objc private func handleCategoryRowTap() {
        showDropdown(for: .category, from: categorySelection)
    }

    @objc private func handleConditionRowTap() {
        showDropdown(for: .condition, from: conditionSelection)
    }

    // MARK: - Inline Dropdown

    fileprivate enum DropdownKind {
        case category
        case condition

        var options: [String] {
            switch self {
            case .category:
                return ["Electronics", "Tools", "Events", "Fitness", "Hobbies", "Outdoor", "Custom"]
            case .condition:
                return ["New", "Good", "Bad"]
            }
        }
    }

    private var dropdownController: InlineDropdownController?

    private func showDropdown(for kind: DropdownKind, from sourceRow: UIView?) {
        guard let sourceRow = sourceRow else { return }

        if let dc = dropdownController {
            if dc.kind == kind {
                dc.dismiss(animated: true)
                dropdownController = nil
                return
            } else {
                dc.dismiss(animated: false)
                dropdownController = nil
            }
        }

        let dc = InlineDropdownController(kind: kind,
                                          options: kind.options,
                                          anchorView: sourceRow,
                                          in: view,
                                          onSelect: { [weak self] (selected: String) in
            guard let self = self else { return }
            switch kind {
            case .category:
                self.selectACategory.text = selected
                self.selectACategory.textColor = .label
            case .condition:
                self.selectCondition.text = selected
                self.selectCondition.textColor = .label
            }
            self.dropdownController = nil
        }, onDismiss: { [weak self] in
            self?.dropdownController = nil
        })

        dropdownController = dc
        dc.present(animated: true)
    }

    // MARK: - Helpers

    private func addTapToStack(_ stack: UIStackView?, action: Selector) {
        guard let stack = stack else { return }
        stack.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: action)
        tap.cancelsTouchesInView = true
        stack.addGestureRecognizer(tap)
        stack.isAccessibilityElement = true
        stack.accessibilityTraits = .button
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
}

// MARK: - InlineDropdownController

private final class InlineDropdownController: NSObject, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    let kind: AddItemDetailViewController.DropdownKind
    private let options: [String]
    private weak var anchorView: UIView?
    private weak var containerView: UIView?

    private let backgroundDismissView = UIView()
    private let table = UITableView(frame: .zero, style: .plain)
    private var tableHeightConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    private let rowHeight: CGFloat = 44
    private let maxVisibleRows: Int = 6
    private let horizontalInset: CGFloat = 20
    private let cornerRadius: CGFloat = 12

    private let onSelect: (String) -> Void
    private let onDismiss: () -> Void

    init(kind: AddItemDetailViewController.DropdownKind,
         options: [String],
         anchorView: UIView,
         in containerView: UIView,
         onSelect: @escaping (String) -> Void,
         onDismiss: @escaping () -> Void) {
        self.kind = kind
        self.options = options
        self.anchorView = anchorView
        self.containerView = containerView
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        super.init()
        setupUI()
    }

    private func setupUI() {
        guard let container = containerView else { return }

        backgroundDismissView.backgroundColor = UIColor.black.withAlphaComponent(0.001)
        backgroundDismissView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backgroundDismissView)
        NSLayoutConstraint.activate([
            backgroundDismissView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backgroundDismissView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backgroundDismissView.topAnchor.constraint(equalTo: container.topAnchor),
            backgroundDismissView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let bgTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        bgTap.delegate = self
        backgroundDismissView.addGestureRecognizer(bgTap)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.isScrollEnabled = true
        table.separatorInset = .zero
        table.layer.cornerRadius = cornerRadius
        table.layer.masksToBounds = true
        table.layer.borderColor = UIColor.systemGray4.cgColor
        table.layer.borderWidth = 1
        table.backgroundColor = .systemBackground

        container.addSubview(table)

        leadingConstraint = table.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset)
        trailingConstraint = table.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset)

        if let anchor = anchorView {
            topConstraint = table.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: 8)
        } else {
            topConstraint = table.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 8)
        }

        tableHeightConstraint = table.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            leadingConstraint, trailingConstraint,
            topConstraint,
            tableHeightConstraint!
        ].compactMap { $0 })

        table.register(UITableViewCell.self, forCellReuseIdentifier: "DropCell")
    }

    func present(animated: Bool) {
        guard let container = containerView else { return }
        container.layoutIfNeeded()
        let finalHeight = min(CGFloat(options.count) * rowHeight, CGFloat(maxVisibleRows) * rowHeight)
        tableHeightConstraint?.constant = finalHeight
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                container.layoutIfNeeded()
            }
        } else {
            container.layoutIfNeeded()
        }
    }

    func dismiss(animated: Bool) {
        guard let container = containerView else { return }
        tableHeightConstraint?.constant = 0
        let cleanup = {
            self.table.removeFromSuperview()
            self.backgroundDismissView.removeFromSuperview()
            self.onDismiss()
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
                container.layoutIfNeeded()
            } completion: { _ in
                cleanup()
            }
        } else {
            container.layoutIfNeeded()
            cleanup()
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DropCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = options[indexPath.row]
        config.textProperties.font = .systemFont(ofSize: 16)
        config.textProperties.color = .label
        cell.contentConfiguration = config
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect(options[indexPath.row])
        dismiss(animated: true)
    }

    // MARK: - Dismissal

    @objc private func handleBackgroundTap() {
        dismiss(animated: true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: table) == true {
            return false
        }
        return true
    }
}

