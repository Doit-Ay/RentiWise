//
//  PriceAnalyzerScreenTwoViewController.swift
//  PriceAnalyzer
//
//  Created by admin67 on 13/11/25.
//

import UIKit

class PriceAnalyzerScreenTwoViewController: UIViewController {

    @IBOutlet weak var ViewchangePrice: UIView!

    // Keep a reference to the currently embedded child VC
    private var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Provide a default title if the caller didn't set one
        if title?.isEmpty ?? true {
            title = "Analyze Result"
        }
        view.backgroundColor = .systemBackground

        // Load default segment content (assumes segment index 0 = Price Factors)
        switchToSegment(index: 0)
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

    // Segmented control action
    @IBAction func innersegmentPrice(_ sender: UISegmentedControl) {
        switchToSegment(index: sender.selectedSegmentIndex)
    }

    // MARK: - Child containment

    private func switchToSegment(index: Int) {
        // Instantiate the appropriate child controller using its XIB
        let newChild: UIViewController

        switch index {
        case 0:
            // Price Factors
            newChild = PriceFactorViewController(nibName: "PriceFactorViewController", bundle: nil)
        case 1:
            // Compare
            newChild = CompareViewController(nibName: "CompareViewController", bundle: nil)
        case 2:
            // What-if
            newChild = WhatifViewController(nibName: "WhatifViewController", bundle: nil)
        default:
            // Fallback to first segment if an unexpected index is provided
            newChild = PriceFactorViewController(nibName: "PriceFactorViewController", bundle: nil)
        }

        embed(child: newChild, in: ViewchangePrice)
    }

    private func embed(child newChild: UIViewController, in container: UIView) {
        // Remove existing child if any
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        // Add new child
        addChild(newChild)
        newChild.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(newChild.view)

        // Pin to container view edges
        NSLayoutConstraint.activate([
            newChild.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            newChild.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            newChild.view.topAnchor.constraint(equalTo: container.topAnchor),
            newChild.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        newChild.didMove(toParent: self)
        currentChild = newChild
    }
}
