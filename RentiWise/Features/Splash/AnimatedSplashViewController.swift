//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  EXACTLY 2 animated rectangles + the original Rentiwise_logo PDF.
//  No extra labels, no duplicate text.
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    // Colors matching the original logo rectangles
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

    func beginSplashSequence() {
        animateIn()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in self?.dismissSplash() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.dismissSplash() }
    }

    private func buildUI() {
        let screenW = UIScreen.main.bounds.width
        let rectSide = screenW * 0.85
        let cr: CGFloat = 44

        // ── LEFT RECT (Light Teal) ──
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

        // ── RIGHT RECT (Medium Teal) ──
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

        // ── LOGO (Rentiwise_logo.pdf) ──
        // This asset already contains BOTH the shield AND the "Rentiwise" text!
        logoImageView.image = UIImage(named: "Rentiwise_logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = .clear
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65),
            logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor),
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = UIScreen.main.bounds.width
        // Push rects fully off screen
        rectLeft.transform  = CGAffineTransform(translationX: -screenW, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW, y: 0)
        
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
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
        // Logo fades in
        UIView.animate(withDuration: 0.5, delay: 0.55,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: []) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = .identity
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
