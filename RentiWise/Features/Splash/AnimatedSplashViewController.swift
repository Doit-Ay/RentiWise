//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  ONE animated splash screen. No static launch screen logo.
//
//  Animation sequence:
//    0.0s  — Left teal rectangle slides in from left screen edge
//    0.12s — Right teal rectangle slides in from right screen edge
//           Both park with their outer edges flush to screen borders,
//           overlapping in the center
//    0.55s — Logo image fades in + gentle scale-up
//    2.8s  — Everything fades out → app
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    // Colors matching the logo asset
    private let tealLight  = UIColor(red: 0xD6/255.0, green: 0xEB/255.0, blue: 0xEF/255.0, alpha: 1.0)
    private let tealMedium = UIColor(red: 0xC4/255.0, green: 0xE1/255.0, blue: 0xE7/255.0, alpha: 1.0)

    private let rectLeft  = UIView()
    private let rectRight = UIView()
    private let logoImageView = UIImageView()

    private var didDismiss = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.clipsToBounds = true
        buildUI()
        hideBeforeAnimation()
    }

    // Called by SceneDelegate right after addChild
    func beginSplashSequence() {
        animateIn()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in self?.dismiss() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.dismiss() }
    }

    // MARK: - Layout

    private func buildUI() {
        let w = UIScreen.main.bounds.width
        // Each rect is 70% of screen width → they overlap 40% in center
        let rectW = w * 0.70
        let rectH = rectW   // square
        let cr: CGFloat = 36

        // LEFT rect — leading edge pinned to screen left
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)
        NSLayoutConstraint.activate([
            rectLeft.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rectLeft.widthAnchor.constraint(equalToConstant: rectW),
            rectLeft.heightAnchor.constraint(equalToConstant: rectH),
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
        ])

        // RIGHT rect — trailing edge pinned to screen right
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)
        NSLayoutConstraint.activate([
            rectRight.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rectRight.widthAnchor.constraint(equalToConstant: rectW),
            rectRight.heightAnchor.constraint(equalToConstant: rectH),
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
        ])

        // LOGO — on top, centered, same as the original launch screen size
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65),
            logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor),
        ])
    }

    // MARK: - Pre-animation

    private func hideBeforeAnimation() {
        let w = UIScreen.main.bounds.width

        // Push rects fully off-screen to their respective sides
        rectLeft.transform  = CGAffineTransform(translationX: -w, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  w, y: 0)

        // Logo hidden
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
    }

    // MARK: - Animation

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

        // Logo fades in + scales up after rects land
        UIView.animate(withDuration: 0.45, delay: 0.55, options: [.curveEaseOut]) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        guard !didDismiss else { return }
        didDismiss = true
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.view.alpha = 0
        } completion: { _ in
            self.onComplete?()
        }
    }
}
