// UIExtensions+Glass.swift
import UIKit

extension UIView {
    // A simpler frosted glass effect with optional shadow, border, tint overlay and highlight.
    // Note: The project already includes a richer version named `applyGlassEffect` in UIExtension.swift.
    // This simple variant is kept for optional use under a different name to avoid redeclaration conflicts.
    func applyGlassEffectSimple(
        cornerRadius: CGFloat = 12,
        style: UIBlurEffect.Style = .systemMaterial,
        addsVibrancy: Bool = false,
        showsShadow: Bool = true,
        borderAlpha: CGFloat = 0.25,
        tintColorOverride: UIColor? = nil,
        tintAlpha: CGFloat = 0.18,
        showsHighlight: Bool = true,
        highlightAlpha: CGFloat = 0.12
    ) {
        // Remove previous layers (identified by tags)
        let blurTag = 999_001
        let tintTag = 999_002
        let highlightTag = 999_003

        subviews
            .filter { $0.tag == blurTag || $0.tag == tintTag || $0.tag == highlightTag }
            .forEach { $0.removeFromSuperview() }

        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false

        // Blur
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: style))
        blur.tag = blurTag
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blur, at: 0)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        blur.layer.cornerRadius = cornerRadius
        blur.clipsToBounds = true

        // Optional vibrancy
        if addsVibrancy {
            if let blurEffect = blur.effect as? UIBlurEffect {
                let vibrancy = UIVibrancyEffect(blurEffect: blurEffect)
                let vibrancyView = UIVisualEffectView(effect: vibrancy)
                vibrancyView.translatesAutoresizingMaskIntoConstraints = false
                blur.contentView.addSubview(vibrancyView)
                NSLayoutConstraint.activate([
                    vibrancyView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
                    vibrancyView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
                    vibrancyView.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
                    vibrancyView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
                ])
            }
        }

        // Optional tint overlay for “whiter” glass looks
        if let tint = tintColorOverride {
            let overlay = UIView()
            overlay.tag = tintTag
            overlay.backgroundColor = tint.withAlphaComponent(tintAlpha)
            overlay.isUserInteractionEnabled = false
            overlay.translatesAutoresizingMaskIntoConstraints = false
            blur.contentView.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
            ])
        }

        // Optional top highlight sheen
        if showsHighlight {
            let h = UIView()
            h.tag = highlightTag
            h.isUserInteractionEnabled = false
            h.translatesAutoresizingMaskIntoConstraints = false
            h.backgroundColor = UIColor.white.withAlphaComponent(highlightAlpha)
            blur.contentView.addSubview(h)
            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
                h.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
                h.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
                h.heightAnchor.constraint(equalTo: blur.contentView.heightAnchor, multiplier: 0.35)
            ])
        }

        // Border + shadow
        layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
        layer.borderWidth = borderAlpha > 0 ? 0.5 : 0
        if showsShadow {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.12
            layer.shadowRadius = 10
            layer.shadowOffset = CGSize(width: 0, height: 6)
        } else {
            layer.shadowOpacity = 0
        }
    }
}
//end
