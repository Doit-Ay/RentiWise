//
//  PriceAnalyzerScreenTwoViewController.swift
//  PriceAnalyzer
//
//  Created by admin67 on 13/11/25.
//

import UIKit

class PriceAnalyzerScreenTwoViewController: UIViewController {

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Price Analyzer"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Screen Two"
        subtitleLabel.font = .preferredFont(forTextStyle: .title2)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        root.addSubview(titleLabel)
        root.addSubview(subtitleLabel)
        root.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            closeButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            closeButton.centerXAnchor.constraint(equalTo: root.centerXAnchor)
        ])

        self.view = root
    }

    @objc private func didTapClose() {
        if let nav = navigationController {
            if nav.viewControllers.first === self { // presented inside a nav controller
                dismiss(animated: true)
            } else {
                nav.popViewController(animated: true)
            }
        } else if presentingViewController != nil {
            dismiss(animated: true)
        }
    }
}
