//
//  VerificationBadgeStripView.swift
//  RentiWise
//
//  Reusable horizontal pill strip showing verification status badges.
//  Shows "📱 Phone Verified" and/or "🎓 College Verified" pills.
//  Shows "Unverified" grey pill if neither verification present.
//

import UIKit

final class VerificationBadgeStripView: UIView {

    private let stackView = UIStackView()

    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Configure with verification status.
    /// - Parameters:
    ///   - isPhoneVerified: whether user's phone is verified
    ///   - isCollegeVerified: whether user's college email is verified
    func configure(isPhoneVerified: Bool, isCollegeVerified: Bool) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if !isPhoneVerified && !isCollegeVerified {
            stackView.addArrangedSubview(makePill(text: "Unverified", teal: false))
            return
        }

        if isPhoneVerified {
            stackView.addArrangedSubview(makePill(text: "📱 Phone Verified", teal: true))
        }

        if isCollegeVerified {
            stackView.addArrangedSubview(makePill(text: "🎓 College Verified", teal: true))
        }
    }

    private func makePill(text: String, teal: Bool) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = teal ? .white : .secondaryLabel

        let pill = UIView()
        pill.backgroundColor = teal ? brandTeal : UIColor.systemGray5
        pill.layer.cornerRadius = 8
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -6),
        ])
        return pill
    }
}
