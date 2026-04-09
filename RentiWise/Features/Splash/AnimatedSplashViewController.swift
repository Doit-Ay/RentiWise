//
//  AnimatedSplashViewController.swift
//  RentiWise
//
//  Height restored to normal (squares).
//  To hide the outer corner radii (keep them flush against the screen border),
//  we push the leading/trailing edges off-screen by exactly the corner radius.
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
        let screenW = view.bounds.width
        
        // Height is back to normal!
        let rectHeight = screenW * 0.85
        let visibleWidth = screenW * 0.85
        let cr: CGFloat = 48

        // ── LEFT RECT ──
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)
        NSLayoutConstraint.activate([
            // Push left edge off-screen by exactly the corner radius
            // so the visible part touches the screen border in a perfectly straight line
            rectLeft.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -cr),
            // Add `cr` to width so the visible width remains `visibleWidth`
            rectLeft.widthAnchor.constraint(equalToConstant: visibleWidth + cr),
            rectLeft.heightAnchor.constraint(equalToConstant: rectHeight),
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -screenW * 0.05)
        ])

        // ── RIGHT RECT ──
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)
        NSLayoutConstraint.activate([
            // Push right edge off-screen by exactly the corner radius
            rectRight.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: cr),
            rectRight.widthAnchor.constraint(equalToConstant: visibleWidth + cr),
            rectRight.heightAnchor.constraint(equalToConstant: rectHeight),
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: screenW * 0.05)
        ])

        // ── LOGO (Native PDF containing Shield + Text, no duplicates!) ──
        logoImageView.image = UIImage(named: "Rentiwise_logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = .clear
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor), // perfectly centered
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65),
            logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor)
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = view.bounds.width
        
        // Push rects fully off screen
        rectLeft.transform  = CGAffineTransform(translationX: -screenW, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW, y: 0)
        
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    private func animateIn() {
        // Slide in
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectLeft.transform = .identity
        }
        
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
