//
//  AddItemPricingViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPricingViewController: UIViewController, UITextFieldDelegate {

    // Injected draft from previous screen
    var draft: AddItemDraft = AddItemDraft()

    @IBOutlet weak var pricePerDay: UITextField!
    @IBOutlet weak var refundableDeposit: UITextField!

    // Feature 3: High-value deposit warning
    private let depositWarningLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ High-value items may need extra trust coordination with your borrower."
        label.font = .systemFont(ofSize: 13)
        label.textColor = .systemOrange
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Optional: set keyboard types for numeric entry
        pricePerDay?.keyboardType = .decimalPad
        refundableDeposit?.keyboardType = .decimalPad

        // Reuse the second numeric field as declared value for the beta trust flow.
        pricePerDay?.text = draft.pricePerDay > 0 ? String(format: "%.0f", draft.pricePerDay) : ""
        refundableDeposit?.text = draft.declaredValue > 0 ? String(draft.declaredValue) : ""
        refundableDeposit?.placeholder = "₹ estimated item value"

        // 1) Tap anywhere to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // 2) Add Done accessory above decimal keypad (optional but helpful)
        let doneToolbar = makeDoneToolbar()
        pricePerDay?.inputAccessoryView = doneToolbar
        refundableDeposit?.inputAccessoryView = doneToolbar

        // Feature 3: Wire deposit field delegate and add warning label
        refundableDeposit?.delegate = self
        if let depositField = refundableDeposit {
            if let sv = depositField.superview {
                sv.addSubview(depositWarningLabel)
                NSLayoutConstraint.activate([
                    depositWarningLabel.topAnchor.constraint(equalTo: depositField.bottomAnchor, constant: 4),
                    depositWarningLabel.leadingAnchor.constraint(equalTo: depositField.leadingAnchor),
                    depositWarningLabel.trailingAnchor.constraint(equalTo: depositField.trailingAnchor),
                ])
            }
        }
    }

    // Dismiss keyboard utility
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // Toolbar with Done button for inputs that need an explicit dismiss
    private func makeDoneToolbar() -> UIToolbar {
        let tb = UIToolbar()
        tb.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        tb.items = [flex, done]
        return tb
    }

    @IBAction func continueTapped(_ sender: UIButton) {
        // Validate required fields on this screen
        guard let priceText = pricePerDay.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !priceText.isEmpty,
              let price = Double(priceText),
              price > 0
        else {
            presentAlert(title: "Missing or Invalid Price", message: "Enter a valid price per day greater than 0.")
            return
        }

        guard let declaredValueText = refundableDeposit.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !declaredValueText.isEmpty,
              let declaredValue = Int(declaredValueText),
              declaredValue > 0
        else {
            presentAlert(title: "Missing or Invalid Declared Value", message: "Enter the item's declared value in INR.")
            return
        }
        
        if declaredValue > 5000 {
            presentAlert(title: "Value Limit", message: "For the beta launch, items can be listed up to 5,000 INR in value.")
            return
        }

        // Defensive checks for previous steps (optional but helpful)
        if draft.images.isEmpty {
            presentAlert(title: "Missing Photos", message: "Please add at least one photo on the first step.")
            return
        }
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            presentAlert(title: "Missing Title", message: "Please enter a title on the details step.")
            return
        }
        if draft.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            presentAlert(title: "Missing Category", message: "Please select a category on the details step.")
            return
        }
        if draft.condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            presentAlert(title: "Missing Condition", message: "Please select a condition on the details step.")
            return
        }
        if draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            presentAlert(title: "Missing Description", message: "Please add a short description on the details step.")
            return
        }

        // Persist validated values into the draft
        draft.pricePerDay = price
        draft.depositAmount = 0
        draft.declaredValue = declaredValue

        // Proceed to the Publish step (XIB-backed)
        let vc = AddItemPublishViewController(nibName: "AddItemPublishViewController", bundle: nil)
        vc.title = "Add item"
        vc.hidesBottomBarWhenPushed = true
        vc.draft = draft

        // Always push on existing navigation stack
        guard let nav = navigationController else {
            assertionFailure("AddItemPricingViewController must be pushed inside a UINavigationController within the tab bar.")
            return
        }
        nav.pushViewController(vc, animated: true)
    }

    // MARK: - Alert helper
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - UITextFieldDelegate (Feature 3: Value Cap Warning)
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == refundableDeposit {
            // Compute new text after replacement
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return true }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            let value = Double(updatedText) ?? 0
            depositWarningLabel.isHidden = (value <= 10000)
        }
        return true
    }
}
