//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  Final result looks EXACTLY like the original launch screen (logo.png).
//  But the 2 background rectangles are animated (slide from screen edges).
//
//  Layer stack:
//    1. rectLeft  (teal rounded rect, pinned to left edge)
//    2. rectRight (teal rounded rect, pinned to right edge)
//    3. shieldImageView (Rentiwise_logo PDF — shield icon, transparent bg)
//    4. nameLabel ("Rentiwise" text)
//
//  Animation:
//    0.0s  — Left rect slides in from left screen edge
//    0.12s — Right rect slides in from right screen edge
//    0.55s — Shield icon fades in + scales up
//    0.7s  — "Rentiwise" text fades in
//    2.8s  — Everything fades out
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    // Colors matching the logo.png rectangles exactly
    private let tealLight  = UIColor(red: 0xD6/255.0, green: 0xEB/255.0, blue: 0xEF/255.0, alpha: 1.0)
    private let tealMedium = UIColor(red: 0xC4/255.0, green: 0xE1/255.0, blue: 0xE7/255.0, alpha: 1.0)
    private let brandTeal  = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    private let rectLeft  = UIView()
    private let rectRight = UIView()
    private let shieldImageView = UIImageView()
    private let nameLabel = UILabel()

    private var didDismiss = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.clipsToBounds = true
        buildUI()
        hideBeforeAnimation()
    }

    func beginSplashSequence() {
        animateIn()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in self?.dismissSplash() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.dismissSplash() }
    }

    private func buildUI() {
        let screenW = UIScreen.main.bounds.width
        let rectSide = screenW * 0.85
        let cr: CGFloat = 44

        // ── LEFT RECT ──
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)
        NSLayoutConstraint.activate([
            rectLeft.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rectLeft.widthAnchor.constraint(equalToConstant: rectSide),
            rectLeft.heightAnchor.constraint(equalToConstant: rectSide),
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
        ])

        // ── RIGHT RECT ──
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)
        NSLayoutConstraint.activate([
            rectRight.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rectRight.widthAnchor.constraint(equalToConstant: rectSide),
            rectRight.heightAnchor.constraint(equalToConstant: rectSide),
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
        ])

        // ── SHIELD ICON (Rentiwise_logo — PDF vector, transparent background) ──
        shieldImageView.image = UIImage(named: "Rentiwise_logo")
        shieldImageView.contentMode = .scaleAspectFit
        shieldImageView.backgroundColor = .clear
        shieldImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shieldImageView)
        NSLayoutConstraint.activate([
            shieldImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shieldImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -55),
            shieldImageView.widthAnchor.constraint(equalToConstant: 160),
            shieldImageView.heightAnchor.constraint(equalToConstant: 160),
        ])

        // ── "Rentiwise" TEXT ──
        nameLabel.text = "Rentiwise"
        nameLabel.font = .systemFont(ofSize: 30, weight: .bold)
        nameLabel.textColor = brandTeal
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 8),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = UIScreen.main.bounds.width
        rectLeft.transform  = CGAffineTransform(translationX: -screenW, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW, y: 0)
        shieldImageView.alpha = 0
        shieldImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        nameLabel.alpha = 0
        nameLabel.transform = CGAffineTransform(translationX: 0, y: 12)
    }

    private func animateIn() {
        // Left rect slides in from left
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectLeft.transform = .identity
        }
        // Right rect slides in from right
        UIView.animate(withDuration: 0.6, delay: 0.12,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectRight.transform = .identity
        }
        // Shield fades in
        UIView.animate(withDuration: 0.5, delay: 0.55,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: []) {
            self.shieldImageView.alpha = 1
            self.shieldImageView.transform = .identity
        }
        // Name fades in
        UIView.animate(withDuration: 0.4, delay: 0.7, options: [.curveEaseOut]) {
            self.nameLabel.alpha = 1
            self.nameLabel.transform = .identity
        }
    }

    private func dismissSplash() {
        guard !didDismiss else { return }
        didDismiss = true
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.view.alpha = 0
        } completion: { _ in
            self.onComplete?()
        }
    }
}
