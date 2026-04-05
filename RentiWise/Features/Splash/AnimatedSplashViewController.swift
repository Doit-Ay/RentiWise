//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  Premium animated splash overlay that plays after the static LaunchScreen.
//
//  Animation Principles:
//    • Layered reveal — staggered background shapes create depth
//    • Spring physics — organic, tactile logo entrance
//    • Sequential disclosure — elements appear one-by-one to guide the eye
//    • Graceful exit — the whole layer dissolves to reveal the real UI
//
//  Timing:
//    Total splash duration is capped at 2.8 seconds (animation + hold + fade).
//    A hard failsafe at 3.5s guarantees removal even if something goes wrong.
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    // MARK: - Callback
    var onComplete: (() -> Void)?

    // MARK: - Brand Palette
    private let brandTeal   = UIColor(red: 0x70/255, green: 0xA7/255, blue: 0xB4/255, alpha: 1)
    private let tealDark    = UIColor(red: 0x4A/255, green: 0x8A/255, blue: 0x9A/255, alpha: 1)
    private let tealMid     = UIColor(red: 0x5D/255, green: 0xA9/255, blue: 0xB6/255, alpha: 1)
    private let tealLight   = UIColor(red: 0x8E/255, green: 0xC5/255, blue: 0xCF/255, alpha: 1)

    // MARK: - UI Elements
    private let bgRect1 = UIView()
    private let bgRect2 = UIView()
    private let bgRect3 = UIView()
    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let taglineLabel = UILabel()

    /// Prevents dismiss from firing twice
    private var didDismiss = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupBackgroundShapes()
        setupLogo()
        setupLabels()
        hideAllElements()
    }

    // MARK: - Public API (called by SceneDelegate after adding as child)

    /// Starts the animation + schedules the timed dismiss.
    /// Call this explicitly right after adding the splash view — do NOT rely on viewDidAppear.
    func beginSplashSequence() {
        runAnimationSequence()

        // Dismiss after animation completes + short hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.dismissSplash()
        }

        // Absolute failsafe — always remove, no matter what
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.dismissSplash()
        }
    }

    // MARK: - Setup

    private func setupBackgroundShapes() {
        let shapes = [bgRect1, bgRect2, bgRect3]
        let colors = [tealLight.withAlphaComponent(0.25),
                      tealMid.withAlphaComponent(0.20),
                      brandTeal.withAlphaComponent(0.15)]
        let sizes: [(CGFloat, CGFloat)] = [(280, 280), (240, 240), (200, 200)]
        let rotations: [CGFloat] = [15, -10, 20]

        for (i, shape) in shapes.enumerated() {
            shape.backgroundColor = colors[i]
            shape.layer.cornerRadius = 40
            shape.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(shape)

            NSLayoutConstraint.activate([
                shape.centerXAnchor.constraint(equalTo: view.centerXAnchor,
                                               constant: CGFloat([-20, 30, -10][i])),
                shape.centerYAnchor.constraint(equalTo: view.centerYAnchor,
                                               constant: CGFloat([-60, -30, -80][i])),
                shape.widthAnchor.constraint(equalToConstant: sizes[i].0),
                shape.heightAnchor.constraint(equalToConstant: sizes[i].1),
            ])

            shape.transform = CGAffineTransform(rotationAngle: rotations[i] * .pi / 180)
        }
    }

    private func setupLogo() {
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            logoImageView.widthAnchor.constraint(equalToConstant: 160),
            logoImageView.heightAnchor.constraint(equalToConstant: 160),
        ])
    }

    private func setupLabels() {
        nameLabel.text = "RentiWise"
        nameLabel.font = .systemFont(ofSize: 34, weight: .bold)
        nameLabel.textColor = tealDark
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)

        taglineLabel.text = "Rent Smarter. Live Better."
        taglineLabel.font = .systemFont(ofSize: 16, weight: .medium)
        taglineLabel.textColor = brandTeal
        taglineLabel.textAlignment = .center
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            taglineLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Pre-animation State

    private func hideAllElements() {
        let shapes = [bgRect1, bgRect2, bgRect3]
        let baseRotations: [CGFloat] = [15, -10, 20]
        for (i, shape) in shapes.enumerated() {
            let baseRotation = CGAffineTransform(rotationAngle: baseRotations[i] * .pi / 180)
            shape.alpha = 0
            shape.transform = baseRotation.scaledBy(x: 0.7, y: 0.7)
        }

        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

        nameLabel.alpha = 0
        nameLabel.transform = CGAffineTransform(translationX: 0, y: 20)

        taglineLabel.alpha = 0
        taglineLabel.transform = CGAffineTransform(translationX: 0, y: 15)
    }

    // MARK: - Animation Sequence

    private func runAnimationSequence() {
        let shapes = [bgRect1, bgRect2, bgRect3]
        let baseRotations: [CGFloat] = [15, -10, 20]

        // ── Phase 1: Background shapes stagger in ──
        for (i, shape) in shapes.enumerated() {
            let delay = Double(i) * 0.15
            UIView.animate(
                withDuration: 0.6,
                delay: delay,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut]
            ) {
                shape.alpha = 1
                shape.transform = CGAffineTransform(rotationAngle: baseRotations[i] * .pi / 180)
            }
        }

        // ── Phase 2: Logo springs in ──
        UIView.animate(
            withDuration: 0.7,
            delay: 0.35,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: []
        ) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
        }

        // ── Phase 3: Brand name slides up ──
        UIView.animate(
            withDuration: 0.5,
            delay: 0.7,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.6,
            options: []
        ) {
            self.nameLabel.alpha = 1
            self.nameLabel.transform = .identity
        }

        // ── Phase 4: Tagline fades in ──
        UIView.animate(
            withDuration: 0.4,
            delay: 0.9,
            options: [.curveEaseOut]
        ) {
            self.taglineLabel.alpha = 1
            self.taglineLabel.transform = .identity
        }
    }

    // MARK: - Dismiss

    private func dismissSplash() {
        guard !didDismiss else { return }
        didDismiss = true

        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseIn]) {
            self.view.alpha = 0
        } completion: { _ in
            self.onComplete?()
        }
    }
}
