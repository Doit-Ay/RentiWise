//
//  PriceAnalyzerScreenOneViewController.swift
//  PriceAnalyzer
//
//  Created by admin67 on 13/11/25.
//

import UIKit

class PriceAnalyzerScreenOneViewController: UIViewController {

    // Make this controller fully programmatic to avoid nib/storyboard outlet issues
    override func loadView() {
        let root = UIView()
        root.backgroundColor = .systemBackground

        // Example UI so the screen is visibly working
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Price Analyzer"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Screen One"
        subtitleLabel.font = .preferredFont(forTextStyle: .title2)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        root.addSubview(titleLabel)
        root.addSubview(subtitleLabel)

        let goButton = UIButton(type: .system)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("Go to Screen Two", for: .normal)
        goButton.addTarget(self, action: #selector(didTapGoToScreenTwo), for: .touchUpInside)
        root.addSubview(goButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor)
            ,
            goButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            goButton.centerXAnchor.constraint(equalTo: root.centerXAnchor)
        ])

        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup if needed
    }

    // MARK: - Actions

    @objc private func didTapGoToScreenTwo() {
        let screenTwo = PriceAnalyzerScreenTwoViewController()
        if let nav = self.navigationController {
            nav.pushViewController(screenTwo, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: screenTwo)
            nav.modalPresentationStyle = .automatic
            present(nav, animated: true)
        }
    }

    // MARK: - Convenience navigation helpers

    /// Pushes this screen onto the given navigation controller. If none is provided,
    /// it will try to use the source's navigationController.
    static func push(from source: UIViewController, using navController: UINavigationController? = nil, animated: Bool = true) {
        let vc = PriceAnalyzerScreenOneViewController()
        let nav = navController ?? source.navigationController
        nav?.pushViewController(vc, animated: animated)
    }

    /// Presents this screen modally, optionally embedding in a UINavigationController.
    static func present(from source: UIViewController, embedInNavigationController: Bool = true, animated: Bool = true, modalPresentationStyle: UIModalPresentationStyle = .automatic) {
        let vc = PriceAnalyzerScreenOneViewController()
        if embedInNavigationController {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = modalPresentationStyle
            source.present(nav, animated: animated)
        } else {
            vc.modalPresentationStyle = modalPresentationStyle
            source.present(vc, animated: animated)
        }
    }

}
