//
//  AddItemPricingViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPricingViewController: UIViewController {

    // Injected draft from previous screen
    var draft: AddItemDraft = AddItemDraft()

    @IBOutlet weak var pricePerDay: UITextField!
    @IBOutlet weak var refundableDeposit: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Optional: set keyboard types for numeric entry
        pricePerDay?.keyboardType = .decimalPad
        refundableDeposit?.keyboardType = .decimalPad

        // Prefill if editing
        if draft.pricePerDay > 0 {
            pricePerDay?.text = String(format: "%.2f", draft.pricePerDay)
        }
        if draft.depositAmount >= 0 {
            refundableDeposit?.text = String(format: "%.2f", draft.depositAmount)
        }
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

        guard let depositText = refundableDeposit.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !depositText.isEmpty,
              let deposit = Double(depositText),
              deposit >= 0
        else {
            presentAlert(title: "Missing or Invalid Deposit", message: "Enter a valid refundable deposit (0 or more).")
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
        draft.depositAmount = deposit

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
}

