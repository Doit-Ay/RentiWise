//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  The ONLY way to make the final result look perfectly like the target image
//  is to make `logoImageView` full screen width (multiplier: 1.0) so its built-in
//  rectangles match the screen bounds perfectly.
//  Our animated UIViews slide in and are sized to perfectly overlay the logo's rectangles.
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
        
        // These perfectly match the proportions of the original logo.png
        let rectWidth = screenW * 0.86
        let rectHeight = screenW * 0.86
        let cr: CGFloat = screenW * 0.16

        // ── LOGO IMAGE (Target final state) ──
        // This is 100% width so its built-in rectangles hit the screen edges properly
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = .clear
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            logoImageView.heightAnchor.constraint(equalTo: view.widthAnchor)
        ])

        // ── LEFT RECT (Light Teal) ──
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(rectLeft, belowSubview: logoImageView)
        NSLayoutConstraint.activate([
            rectLeft.leadingAnchor.constraint(equalTo: logoImageView.leadingAnchor),
            rectLeft.widthAnchor.constraint(equalToConstant: rectWidth),
            rectLeft.heightAnchor.constraint(equalToConstant: rectHeight),
            rectLeft.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor, constant: -screenW * 0.04),
        ])

        // ── RIGHT RECT (Medium Teal) ──
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(rectRight, belowSubview: logoImageView)
        NSLayoutConstraint.activate([
            rectRight.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor),
            rectRight.widthAnchor.constraint(equalToConstant: rectWidth),
            rectRight.heightAnchor.constraint(equalToConstant: rectHeight),
            rectRight.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor, constant: screenW * 0.04),
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = UIScreen.main.bounds.width
        // Push rects fully off screen
        rectLeft.transform  = CGAffineTransform(translationX: -screenW, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW, y: 0)
        
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
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
        // Logo fades in nicely on top
        UIView.animate(withDuration: 0.4, delay: 0.6,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 0.2, options: []) {
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
