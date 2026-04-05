//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  EXACTLY 2 RECTANGLES ONLY. 
//  Left rectangle's center is at the left border (half outside).
//  Right rectangle's center is at the right border (half outside).
//  Rentiwise_logo.pdf handles the shield + text. No duplicate UILabels.
//

import UIKit

final class AnimatedSplashViewController: UIViewController {

    var onComplete: (() -> Void)?

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
        
        // As requested: "half outside the border". 
        // We use a width of 1.5 * screen width, so if the center is on the border, 
        // the inner half reaches exactly to the 75% mark of the screen, creating a nice overlap.
        let rectSize = screenW * 1.5
        let cr: CGFloat = rectSize * 0.18 // very rounded corners

        // ── LEFT RECT ──
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)
        NSLayoutConstraint.activate([
            // Center X is at the left border -> left half stays outside!
            rectLeft.centerXAnchor.constraint(equalTo: view.leadingAnchor),
            rectLeft.widthAnchor.constraint(equalToConstant: rectSize),
            rectLeft.heightAnchor.constraint(equalToConstant: rectSize),
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -screenW * 0.15)
        ])

        // ── RIGHT RECT ──
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)
        NSLayoutConstraint.activate([
            // Center X is at the right border -> right half stays outside!
            rectRight.centerXAnchor.constraint(equalTo: view.trailingAnchor),
            rectRight.widthAnchor.constraint(equalToConstant: rectSize),
            rectRight.heightAnchor.constraint(equalToConstant: rectSize),
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: screenW * 0.05)
        ])

        // ── LOGO (contains ONLY shield and text natively) ──
        logoImageView.image = UIImage(named: "Rentiwise_logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = .clear
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -screenW * 0.05), // slightly above center
            // Make logo nice and proportional
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65),
            logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor)
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = UIScreen.main.bounds.width
        
        // Push rects fully off screen
        rectLeft.transform  = CGAffineTransform(translationX: -screenW * 1.5, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW * 1.5, y: 0)
        
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    private func animateIn() {
        // Left rect slides in to its "half offscreen" resting place
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectLeft.transform = .identity
        }
        
        // Right rect slides in to its "half offscreen" resting place
        UIView.animate(withDuration: 0.6, delay: 0.12,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectRight.transform = .identity
        }
        
        // Logo pops in
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
