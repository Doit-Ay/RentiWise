//
//  AnimatedSplashViewController.swift
//  RentiWise
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

        // Each rect = 85% of screen width (same proportions as the logo asset).
        // They overlap ~70% horizontally in the center — just like the logo.
        let rectSide = screenW * 0.85
        let cr: CGFloat = 44

        // LEFT rect — left edge flush with screen left border
        rectLeft.backgroundColor = tealLight
        rectLeft.layer.cornerRadius = cr
        rectLeft.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectLeft)
        NSLayoutConstraint.activate([
            rectLeft.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            rectLeft.widthAnchor.constraint(equalToConstant: rectSide),
            rectLeft.heightAnchor.constraint(equalToConstant: rectSide),
            rectLeft.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
        ])

        // RIGHT rect — right edge flush with screen right border
        rectRight.backgroundColor = tealMedium
        rectRight.layer.cornerRadius = cr
        rectRight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rectRight)
        NSLayoutConstraint.activate([
            rectRight.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            rectRight.widthAnchor.constraint(equalToConstant: rectSide),
            rectRight.heightAnchor.constraint(equalToConstant: rectSide),
            rectRight.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
        ])

        // LOGO — full width, same layout as LaunchScreen
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            logoImageView.heightAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }

    private func hideBeforeAnimation() {
        let screenW = UIScreen.main.bounds.width
        rectLeft.transform  = CGAffineTransform(translationX: -screenW, y: 0)
        rectRight.transform = CGAffineTransform(translationX:  screenW, y: 0)
        logoImageView.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
    }

    private func animateIn() {
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectLeft.transform = .identity
        }
        UIView.animate(withDuration: 0.6, delay: 0.12,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.rectRight.transform = .identity
        }
        UIView.animate(withDuration: 0.45, delay: 0.55, options: [.curveEaseOut]) {
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
