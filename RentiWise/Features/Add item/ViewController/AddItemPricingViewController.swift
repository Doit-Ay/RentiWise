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
    @IBOutlet private weak var declaredValueHintLabel: UILabel!

    private let defaultDeclaredValueHint = "Used for trust checks and borrowing limits."
    private let warningDeclaredValueHint = "⚠️ High-value items may need extra trust coordination with your borrower."

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

        // Feature 3: Wire deposit field delegate and configure helper copy
        refundableDeposit?.delegate = self
        configureDeclaredValueHint(for: Double(draft.declaredValue))
    }

    // Dismiss keyboard utility
    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
            presentAlert(title: "Value Limit", message: "Items can be listed up to 5,000 INR in value.")
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
            configureDeclaredValueHint(for: value)
        }
        return true
    }

    private func configureDeclaredValueHint(for value: Double) {
        let isHighValue = value > 10000
        declaredValueHintLabel.text = isHighValue ? warningDeclaredValueHint : defaultDeclaredValueHint
        declaredValueHintLabel.textColor = isHighValue ? .systemOrange : .opaqueSeparator
        declaredValueHintLabel.numberOfLines = 0
    }
}
