//
//  TrustBadgeView.swift
//  RentiWise
//
//  Reusable pill-shaped badge showing a user's trust tier.
//  Usage: let badge = TrustBadgeView(); badge.badgeTier = "trusted"
//  Tiers: newcomer (grey), trusted (blue), reliable (green), top (gold)
//

import UIKit

final class TrustBadgeView: UIView {

    // MARK: - Public API

    /// Set this to update the badge appearance. Values: "newcomer", "trusted", "reliable", "top"
    var badgeTier: String = "newcomer" {
        didSet { updateAppearance() }
    }

    /// Optional: show the numeric score next to the tier label
    var trustScore: Int? {
        didSet { updateAppearance() }
    }

    // MARK: - Private UI
    private let iconView = UIImageView()
    private let label = UILabel()
    private let stack = UIStackView()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 14
        layer.masksToBounds = true

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.setContentHuggingPriority(.required, for: .horizontal)

        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])

        // Height constraint
        heightAnchor.constraint(equalToConstant: 28).isActive = true

        updateAppearance()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        let tier = TrustTier(rawValue: badgeTier) ?? .newcomer

        backgroundColor = tier.backgroundColor
        iconView.image = UIImage(systemName: tier.sfSymbol)
        iconView.tintColor = .white
        label.textColor = .white

        if let score = trustScore {
            label.text = "\(tier.displayName) · \(score)"
        } else {
            label.text = tier.displayName
        }
    }
}

// MARK: - Trust Tier Definition

enum TrustTier: String {
    case newcomer
    case trusted
    case reliable
    case top

    var displayName: String {
        switch self {
        case .newcomer: return "Newcomer"
        case .trusted: return "Trusted"
        case .reliable: return "Reliable"
        case .top: return "Top Lender"
        }
    }

    var sfSymbol: String {
        switch self {
        case .newcomer: return "person.fill"
        case .trusted: return "checkmark.seal.fill"
        case .reliable: return "shield.fill"
        case .top: return "star.fill"
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .newcomer: return .systemGray
        case .trusted: return .systemBlue
        case .reliable: return .systemGreen
        case .top: return UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0) // Gold/Amber
        }
    }
}
