//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  Exactly 2 rectangles + shield icon + "RentiWise" text.
//  No logo.png (it has rectangles baked in, causing duplicates).
//
//  Sequence:
//    0.0s  — Left rect slides from off-screen left → parks flush to left border
//    0.12s — Right rect slides from off-screen right → parks flush to right border
//    0.55s — Shield icon + "RentiWise" text fade in
//    2.8s  — Everything fades out
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let tealLight  = UIColor(red: 0xD6/255.0, green: 0xEB/255.0, blue: 0xEF/255.0, alpha: 1.0)
    private let tealMedium = UIColor(red: 0xC4/255.0, green: 0xE1/255.0, blue: 0xE7/255.0, alpha: 1.0)
    private let tealDark   = UIColor(red: 0x4A/255.0, green: 0x8A/255.0, blue: 0x9A/255.0, alpha: 1.0)
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

        // ── LEFT RECT — leading edge flush to left screen border ──
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

        // ── RIGHT RECT — trailing edge flush to right screen border ──
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

        // ── SHIELD ICON (just the shield, no background rectangles) ──
        shieldImageView.image = UIImage(named: "shield_icon")
        shieldImageView.contentMode = .scaleAspectFit
        shieldImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shieldImageView)
        NSLayoutConstraint.activate([
            shieldImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shieldImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            shieldImageView.widthAnchor.constraint(equalToConstant: 140),
            shieldImageView.heightAnchor.constraint(equalToConstant: 140),
        ])

        // ── "RentiWise" text ──
        nameLabel.text = "Rentiwise"
        nameLabel.font = .systemFont(ofSize: 30, weight: .bold)
        nameLabel.textColor = brandTeal
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: shieldImageView.bottomAnchor, constant: 12),
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
        nameLabel.transform = CGAffineTransform(translationX: 0, y: 15)
    }

    private func animateIn() {
        // Left rect slides in
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectLeft.transform = .identity
        }
        // Right rect slides in
        UIView.animate(withDuration: 0.6, delay: 0.12,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectRight.transform = .identity
        }
        // Shield pops in
        UIView.animate(withDuration: 0.5, delay: 0.5,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: []) {
            self.shieldImageView.alpha = 1
            self.shieldImageView.transform = .identity
        }
        // Name fades up
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
