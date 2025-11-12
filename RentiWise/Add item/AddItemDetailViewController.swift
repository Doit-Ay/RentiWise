//
//  AddItemDetailViewController.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

class AddItemDetailViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Default title if none set by the previous screen
        if title?.isEmpty ?? true {
            title = "Add item"
        }

        view.backgroundColor = .systemBackground

        // Make the navigation bar clearly visible with a basic appearance
        if let navBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground() // solid background, not transparent
            appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure the navigation bar is visible on this screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Example: programmatic placeholder (remove if using IB)
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
