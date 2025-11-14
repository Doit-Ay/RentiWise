//
//  PriceAnalyzerScreenTwoViewController.swift
//  PriceAnalyzer
//
//  Created by admin67 on 13/11/25.
//

import UIKit

class PriceAnalyzerScreenTwoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Provide a default title if the caller didn't set one
        if title?.isEmpty ?? true {
            title = "Analyze Result"
        }
        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure the navigation bar is visible when pushed
        navigationController?.setNavigationBarHidden(false, animated: animated)

        // If presented modally inside a navigation controller, add a Close button
        if presentingViewController != nil,
           navigationController?.viewControllers.first === self {
            let close = UIBarButtonItem(barButtonSystemItem: .close,
                                        target: self,
                                        action: #selector(closeTapped))
            navigationItem.leftBarButtonItem = close
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
