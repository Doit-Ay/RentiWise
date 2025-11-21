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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBOutlet weak var pricePerDay: UITextField!
    @IBOutlet weak var refundableDeposit: UITextField!

    @IBAction func continueTapped(_ sender: UIButton) {
        // Validate and set price/deposit
        let price = Double(pricePerDay.text ?? "") ?? 0
        let deposit = Double(refundableDeposit.text ?? "") ?? 0
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
}
