//
//  WriteReviewViewController.swift
//  ProductDetails
//
//  Created by user@48 on 13/11/25.
//

import UIKit

class WriteReviewViewController: UIViewController {

    @IBOutlet var StarView: UIView!
    private var starButtons: [UIButton] = []
    private var currentRating: Int = 0 { // 0...5
        didSet { updateStarAppearance() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        StarView.backgroundColor = .systemGroupedBackground
        configureStars()
    }
    
    private func configureStars() {
        // Remove old if reconfiguring
        starButtons.forEach { $0.removeFromSuperview() }
        starButtons.removeAll()

        // Use a horizontal stack view for layout
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        StarView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: StarView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: StarView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: StarView.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: StarView.trailingAnchor)
        ])

        // Create 5 star buttons
        for index in 1...5 {
            let button = UIButton(type: .system)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
            let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
            let empty = UIImage(systemName: "star", withConfiguration: config)
            let filled = UIImage(systemName: "star.fill", withConfiguration: config)

            if #available(iOS 15.0, *) {
                var buttonConfig = UIButton.Configuration.plain()
                buttonConfig.baseForegroundColor = .systemYellow
                buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                button.configuration = buttonConfig
                button.setImage(empty, for: .normal)
                button.setImage(filled, for: .selected)
                
                button.configuration?.background.backgroundColor = .clear
                button.configuration?.background.strokeColor = .clear
                button.configurationUpdateHandler = { btn in
                    var config = btn.configuration
                    config?.background.backgroundColor = .clear
                    config?.background.strokeColor = .clear
                    btn.configuration = config
                }
                button.showsMenuAsPrimaryAction = false
                button.changesSelectionAsPrimaryAction = false
            } else {
                button.setImage(empty, for: .normal)
                button.setImage(filled, for: .selected)
                button.tintColor = UIColor.systemYellow
                button.contentEdgeInsets = .zero
                button.adjustsImageWhenHighlighted = false
                button.setBackgroundImage(UIImage(), for: .highlighted)
            }

            button.addTarget(self, action: #selector(didTapStar(_:)), for: .touchUpInside)
            starButtons.append(button)
            stack.addArrangedSubview(button)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        updateStarAppearance()
    }
    
    @objc private func didTapStar(_ sender: UIButton) {
        let tappedIndex = sender.tag
        if currentRating == tappedIndex { // toggle down when tapping the last selected star
            currentRating = max(0, currentRating - 1)
        } else {
            currentRating = tappedIndex
        }
    }
    
    private func updateStarAppearance() {
        for (i, button) in starButtons.enumerated() {
            button.isSelected = (i < currentRating)
            button.alpha = button.isSelected ? 1.0 : 0.6
        }
        // If you want haptics when rating changes
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    @IBAction func didTapSubmit(_ sender: UIButton) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
