//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  The animated splash brings the static launch screen to life.
//
//  It replicates the logo's two overlapping rounded rectangles as
//  separate UIViews, then slides them in from the LEFT and RIGHT
//  screen edges to converge in the center. Once they settle, the
//  full logo image fades in on top, followed by the wordmark.
//
//  This creates a seamless: static logo → animated logo → app transition.
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    // MARK: - Callback
    var onComplete: (() -> Void)?

    // MARK: - Colors (match the logo's internal rectangle colors)
    private let rectColor1 = UIColor(red: 0xD6/255.0, green: 0xEB/255.0, blue: 0xEF/255.0, alpha: 1.0)
    private let rectColor2 = UIColor(red: 0xC4/255.0, green: 0xE1/255.0, blue: 0xE7/255.0, alpha: 1.0)

    // MARK: - UI
    private let rectLeft  = UIView()
    private let rectRight = UIView()
    private let logoImageView = UIImageView()

    private var didDismiss = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        setPreAnimationState()
    }

    // MARK: - Public

    func beginSplashSequence() {
        runAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.dismissSplash()
        }
        // Absolute failsafe
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.dismissSplash()
        }
    }

    // MARK: - Build

    private func buildUI() {
        let screenW = UIScreen.main.bounds.width

        // Rectangle size matches the logo's internal rounded rects
        // The logo PNG is displayed at ~screenWidth wide, and each internal
        // rect is roughly 75% of the logo width → ~75% of screen width
        let rectSide = screenW * 0.72
        let cornerRadius: CGFloat = rectSide * 0.14   // ~40pt on iPhone 17 Pro

        // ── Left rectangle ──
        rectLeft.backgroundColor = rectColor1
        rectLeft.layer.cornerRadius = cornerRadius
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)

        // ── Right rectangle ──
        rectRight.backgroundColor = rectColor2
        rectRight.layer.cornerRadius = cornerRadius
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)

        // Position them to overlap in the center, matching the logo asset layout.
        // The left rect is offset left and slightly up; the right rect offset right.
        NSLayoutConstraint.activate([
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            rectLeft.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -screenW * 0.06),
            rectLeft.widthAnchor.constraint(equalToConstant: rectSide),
            rectLeft.heightAnchor.constraint(equalToConstant: rectSide),

            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            rectRight.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: screenW * 0.06),
            rectRight.widthAnchor.constraint(equalToConstant: rectSide),
            rectRight.heightAnchor.constraint(equalToConstant: rectSide),
        ])

        // Subtle rotation (matching logo design)
        rectLeft.transform  = CGAffineTransform(rotationAngle: -5 * .pi / 180)
        rectRight.transform = CGAffineTransform(rotationAngle:  7 * .pi / 180)

        // ── Logo image (on top of the rects) ──
        // Sized to match the launch screen: full-width, aspect-fit, vertically centered
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            logoImageView.heightAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }

    // MARK: - Pre-animation state

    private func setPreAnimationState() {
        let screenW = UIScreen.main.bounds.width

        // Rects start pushed to screen edges (off-center) and invisible
        let leftBase  = CGAffineTransform(rotationAngle: -5 * .pi / 180)
        let rightBase = CGAffineTransform(rotationAngle:  7 * .pi / 180)

        rectLeft.alpha = 0
        rectLeft.transform = leftBase.translatedBy(x: -screenW, y: 0)

        rectRight.alpha = 0
        rectRight.transform = rightBase.translatedBy(x: screenW, y: 0)

        // Logo starts invisible — only appears after rects settle
        logoImageView.alpha = 0
    }

    // MARK: - Animation

    private func runAnimation() {
        let leftBase  = CGAffineTransform(rotationAngle: -5 * .pi / 180)
        let rightBase = CGAffineTransform(rotationAngle:  7 * .pi / 180)

        // ── Phase 1: Left rect slides in from left edge ──
        UIView.animate(
            withDuration: 0.7,
            delay: 0.0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.3,
            options: []
        ) {
            self.rectLeft.alpha = 1
            self.rectLeft.transform = leftBase
        }

        // ── Phase 2: Right rect slides in from right edge ──
        UIView.animate(
            withDuration: 0.7,
            delay: 0.12,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.3,
            options: []
        ) {
            self.rectRight.alpha = 1
            self.rectRight.transform = rightBase
        }

        // ── Phase 3: Logo fades in once rects have settled ──
        UIView.animate(
            withDuration: 0.5,
            delay: 0.55,
            options: [.curveEaseOut]
        ) {
            self.logoImageView.alpha = 1
        }
    }

    // MARK: - Dismiss

    private func dismissSplash() {
        guard !didDismiss else { return }
        didDismiss = true

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseIn]) {
            self.view.alpha = 0
        } completion: { _ in
            self.onComplete?()
        }
    }
}
