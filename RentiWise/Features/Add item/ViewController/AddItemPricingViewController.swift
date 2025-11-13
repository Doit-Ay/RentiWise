//
//  AddItemPricingViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPricingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func continueTapped(_ sender: UIButton) {
        // Proceed to the Publish step (XIB-backed)
        let vc = AddItemPublishViewController(nibName: "AddItemPublishViewController", bundle: nil)
        vc.title = "Add item"
        vc.hidesBottomBarWhenPushed = true

        // Always push on existing navigation stack
        guard let nav = navigationController else {
            assertionFailure("AddItemPricingViewController must be pushed inside a UINavigationController within the tab bar.")
            return
        }
        nav.pushViewController(vc, animated: true)
    }
}

