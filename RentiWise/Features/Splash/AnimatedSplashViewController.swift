//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  Animated splash overlay — plays once after the static LaunchScreen.
//
//  Design:
//    The animation mirrors the actual logo asset's visual language:
//    two large, teal-tinted rounded rectangles that overlap in the center.
//    They slide in from opposing sides (left & right) to converge,
//    then the brand logo + wordmark fade in on top.
//
//  Animation Philosophy (iOS best practices):
//    1. Spatial origin — elements come FROM somewhere, giving depth
//    2. Overlap & layering — the two rects build a stage before the star appears
//    3. Ease curves — fast start, gentle landing (easeOut) feels natural
//    4. Stagger — each element arrives 0.15–0.3s apart to guide the eye
//    5. Restraint — only 4 moving parts, nothing flashy or gimmicky
//    6. Seamless exit — the whole screen fades out as one unit
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    // MARK: - Callback
    var onComplete: (() -> Void)?

    // MARK: - Colors (matched to the logo asset)
    private let rectColor1 = UIColor(red: 0xCE/255.0, green: 0xE4/255.0, blue: 0xE9/255.0, alpha: 1.0)  // light teal
    private let rectColor2 = UIColor(red: 0xBB/255.0, green: 0xDA/255.0, blue: 0xE1/255.0, alpha: 1.0)  // slightly deeper
    private let tealDark   = UIColor(red: 0x4A/255.0, green: 0x8A/255.0, blue: 0x9A/255.0, alpha: 1.0)
    private let brandTeal  = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - UI
    private let rectLeft  = UIView()
    private let rectRight = UIView()
    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let taglineLabel = UILabel()

    private var didDismiss = false

    // MARK: - Constants
    private let rectSize: CGFloat = 260
    private let rectCornerRadius: CGFloat = 44

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        setPreAnimationState()
    }

    // MARK: - Public API

    /// Called by SceneDelegate immediately after addChild — kicks off the full sequence.
    func beginSplashSequence() {
        runAnimation()

        // Timed dismiss: 2.8s animation + hold, 3.5s absolute failsafe
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.dismissSplash()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.dismissSplash()
        }
    }

    // MARK: - Build UI

    private func buildUI() {
        // ── Left rectangle ──
        rectLeft.backgroundColor = rectColor1
        rectLeft.layer.cornerRadius = rectCornerRadius
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)

        // ── Right rectangle ──
        rectRight.backgroundColor = rectColor2
        rectRight.layer.cornerRadius = rectCornerRadius
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)

        // Position: both centered vertically, overlapping horizontally
        NSLayoutConstraint.activate([
            // Left rect — centered but offset left by 30pt
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            rectLeft.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -30),
            rectLeft.widthAnchor.constraint(equalToConstant: rectSize),
            rectLeft.heightAnchor.constraint(equalToConstant: rectSize),

            // Right rect — centered but offset right by 30pt, slightly lower
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            rectRight.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 30),
            rectRight.widthAnchor.constraint(equalToConstant: rectSize),
            rectRight.heightAnchor.constraint(equalToConstant: rectSize),
        ])

        // Slight rotation for visual interest (like the logo asset)
        rectLeft.transform = CGAffineTransform(rotationAngle: -6 * .pi / 180)
        rectRight.transform = CGAffineTransform(rotationAngle: 8 * .pi / 180)

        // ── Logo ──
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 200),
        ])

        // ── Brand name ──
        nameLabel.text = "RentiWise"
        nameLabel.font = .systemFont(ofSize: 32, weight: .bold)
        nameLabel.textColor = tealDark
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)

        // ── Tagline ──
        taglineLabel.text = "Rent Smarter. Live Better."
        taglineLabel.font = .systemFont(ofSize: 15, weight: .medium)
        taglineLabel.textColor = brandTeal
        taglineLabel.textAlignment = .center
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            taglineLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Pre-animation state

    private func setPreAnimationState() {
        // Rects: invisible, pushed far offscreen to their respective sides
        let slideDistance: CGFloat = 350
        let leftBaseRotation = CGAffineTransform(rotationAngle: -6 * .pi / 180)
        let rightBaseRotation = CGAffineTransform(rotationAngle: 8 * .pi / 180)

        rectLeft.alpha = 0
        rectLeft.transform = leftBaseRotation.translatedBy(x: -slideDistance, y: 0)

        rectRight.alpha = 0
        rectRight.transform = rightBaseRotation.translatedBy(x: slideDistance, y: 0)

        // Logo & text: invisible
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)

        nameLabel.alpha = 0
        nameLabel.transform = CGAffineTransform(translationX: 0, y: 18)

        taglineLabel.alpha = 0
    }

    // MARK: - Animation

    private func runAnimation() {
        let leftBaseRotation = CGAffineTransform(rotationAngle: -6 * .pi / 180)
        let rightBaseRotation = CGAffineTransform(rotationAngle: 8 * .pi / 180)

        // ── Phase 1: Left rect slides in from the left ──
        UIView.animate(
            withDuration: 0.65,
            delay: 0.0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: []
        ) {
            self.rectLeft.alpha = 1
            self.rectLeft.transform = leftBaseRotation
        }

        // ── Phase 2: Right rect slides in from the right (staggered) ──
        UIView.animate(
            withDuration: 0.65,
            delay: 0.15,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: []
        ) {
            self.rectRight.alpha = 1
            self.rectRight.transform = rightBaseRotation
        }

        // ── Phase 3: Logo fades in and scales up ──
        UIView.animate(
            withDuration: 0.55,
            delay: 0.45,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: []
        ) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
        }

        // ── Phase 4: Brand name slides up into place ──
        UIView.animate(
            withDuration: 0.45,
            delay: 0.75,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.4,
            options: []
        ) {
            self.nameLabel.alpha = 1
            self.nameLabel.transform = .identity
        }

        // ── Phase 5: Tagline fades in softly ──
        UIView.animate(
            withDuration: 0.35,
            delay: 0.95,
            options: [.curveEaseOut]
        ) {
            self.taglineLabel.alpha = 1
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
