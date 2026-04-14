//
//  UIExtension.swift
//  RentiWise
//
//  Created by admin99 on 14/11/25.
//

import UIKit

// MARK: - App-wide Notification Names
extension Notification.Name {
    /// Posted whenever the active viewer location changes (GPS, manual entry, saved address, or map picker).
    /// All screens that filter items by distance should observe this and reload.
    static let locationDidChange = Notification.Name("RW_LocationDidChange")
}

// MARK: - UIView styling helpers (programmatic)
extension UIView {

    public func applyCornersAndBorder(
        cornerRadius: CGFloat = 12,
        masksToBounds: Bool = false,
        borderWidth: CGFloat = 0,
        borderColor: UIColor? = nil
    ) {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = masksToBounds
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor?.cgColor
    }

    public func applyShadow(
        color: UIColor = .black,
        opacity: Float = 0.2,
        radius: CGFloat = 6,
        offset: CGSize = CGSize(width: 0, height: 3),
        shouldRasterize: Bool = false
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = offset
        layer.masksToBounds = false
        layer.shouldRasterize = shouldRasterize
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
        layer.rasterizationScale = scale
    }

    @discardableResult
    public func wrapWithRoundedContentContainer(
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 0,
        borderColor: UIColor? = nil,
        shadowColor: UIColor = .black,
        shadowOpacity: Float = 0.2,
        shadowRadius: CGFloat = 6,
        shadowOffset: CGSize = CGSize(width: 0, height: 3)
    ) -> UIView {
        applyShadow(color: shadowColor,
                    opacity: shadowOpacity,
                    radius: shadowRadius,
                    offset: shadowOffset)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        container.applyCornersAndBorder(cornerRadius: cornerRadius,
                                        masksToBounds: true,
                                        borderWidth: borderWidth,
                                        borderColor: borderColor)
        return container
    }

    // Stronger UIKit "glass" look with optional tint and highlight overlay.
    public func applyGlassEffect(
        cornerRadius: CGFloat = 16,
        style: UIBlurEffect.Style = .systemThickMaterial, // heavier by default
        addsVibrancy: Bool = false,
        showsShadow: Bool = true,
        borderAlpha: CGFloat = 0.25,
        // New: subtle tint over blur to increase perceived opacity/contrast
        tintColorOverride: UIColor? = nil,
        tintAlpha: CGFloat = 0.08,
        // New: specular highlight gradient at top
        showsHighlight: Bool = true,
        highlightAlpha: CGFloat = 0.15
    ) {
        let blurTag = 987_654
        let tintTag = 987_655
        let highlightTag = 987_656

        // Blur
        let blurView: UIVisualEffectView
        if let existing = viewWithTag(blurTag) as? UIVisualEffectView {
            blurView = existing
            blurView.effect = UIBlurEffect(style: style)
            blurView.isUserInteractionEnabled = false
        } else {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: style))
            blur.tag = blurTag
            blur.translatesAutoresizingMaskIntoConstraints = false
            // Decorative glass layers should never block taps on controls beneath them.
            blur.isUserInteractionEnabled = false
            insertSubview(blur, at: 0)
            NSLayoutConstraint.activate([
                blur.leadingAnchor.constraint(equalTo: leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: trailingAnchor),
                blur.topAnchor.constraint(equalTo: topAnchor),
                blur.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            if addsVibrancy, let blurEffect = blur.effect as? UIBlurEffect {
                let vibrancy = UIVibrancyEffect(blurEffect: blurEffect)
                let vibrancyView = UIVisualEffectView(effect: vibrancy)
                vibrancyView.translatesAutoresizingMaskIntoConstraints = false
                vibrancyView.isUserInteractionEnabled = false
                blur.contentView.addSubview(vibrancyView)
                NSLayoutConstraint.activate([
                    vibrancyView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
                    vibrancyView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
                    vibrancyView.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
                    vibrancyView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
                ])
            }
            blurView = blur
        }

        // Rounded mask for blur
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false
        blurView.layer.cornerRadius = cornerRadius
        blurView.layer.masksToBounds = true

        // Border
        if borderAlpha > 0 {
            let pixelScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
            layer.borderWidth = 1.0 / pixelScale
            layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor = nil
        }

        // Stronger shadow
        if showsShadow {
            applyShadow(color: .black, opacity: 0.18, radius: 14, offset: CGSize(width: 0, height: 8))
        } else {
            layer.shadowOpacity = 0
        }

        // Optional tint layer to increase opacity/contrast
        let effectiveTint: UIColor
        if let tint = tintColorOverride {
            effectiveTint = tint
        } else {
            // default: white in light mode, black in dark mode
            effectiveTint = (traitCollection.userInterfaceStyle == .dark) ? UIColor.white : UIColor.black
        }

        let tintView: UIView
        if let existing = viewWithTag(tintTag) {
            tintView = existing
            tintView.backgroundColor = effectiveTint.withAlphaComponent(tintAlpha)
        } else {
            let t = UIView()
            t.tag = tintTag
            t.translatesAutoresizingMaskIntoConstraints = false
            t.isUserInteractionEnabled = false
            t.backgroundColor = effectiveTint.withAlphaComponent(tintAlpha)
            insertSubview(t, aboveSubview: blurView)
            NSLayoutConstraint.activate([
                t.leadingAnchor.constraint(equalTo: leadingAnchor),
                t.trailingAnchor.constraint(equalTo: trailingAnchor),
                t.topAnchor.constraint(equalTo: topAnchor),
                t.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            t.layer.cornerRadius = cornerRadius
            t.layer.masksToBounds = true
            tintView = t
        }

        // Optional top highlight gradient
        if showsHighlight {
            let container: GradientHighlightView
            if let existing = viewWithTag(highlightTag) as? GradientHighlightView {
                container = existing
                container.updateColors(
                    top: UIColor.white.withAlphaComponent(highlightAlpha),
                    bottom: UIColor.white.withAlphaComponent(0)
                )
            } else {
                container = GradientHighlightView()
                container.tag = highlightTag
                container.isUserInteractionEnabled = false
                container.translatesAutoresizingMaskIntoConstraints = false
                container.layer.cornerRadius = cornerRadius
                container.layer.masksToBounds = true
                container.updateColors(
                    top: UIColor.white.withAlphaComponent(highlightAlpha),
                    bottom: UIColor.white.withAlphaComponent(0)
                )
                insertSubview(container, aboveSubview: tintView)
                NSLayoutConstraint.activate([
                    container.leadingAnchor.constraint(equalTo: leadingAnchor),
                    container.trailingAnchor.constraint(equalTo: trailingAnchor),
                    container.topAnchor.constraint(equalTo: topAnchor),
                    container.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.35)
                ])
            }
        } else {
            viewWithTag(highlightTag)?.removeFromSuperview()
        }

        backgroundColor = .clear
    }

    // MARK: - Thin colored rim (no center fill)
    public func applyTealRim(
        color: UIColor,
        cornerRadius: CGFloat,
        thickness: CGFloat = 6,
        opacity: Float = 0.18
    ) {
        // Remove previous rim layers
        layer.sublayers?
            .filter { $0.name?.hasPrefix("rimLayer_") == true }
            .forEach { $0.removeFromSuperlayer() }

        let bounds = self.bounds.integral
        guard bounds.width > 0, bounds.height > 0 else { return }

        func makeGradientLayer(name: String, frame: CGRect, start: CGPoint, end: CGPoint) -> CAGradientLayer {
            let g = CAGradientLayer()
            g.name = name
            g.frame = frame
            g.colors = [
                color.withAlphaComponent(CGFloat(opacity)).cgColor,
                color.withAlphaComponent(0).cgColor
            ]
            g.startPoint = start
            g.endPoint = end
            return g
        }

        // Top rim
        let top = makeGradientLayer(name: "rimLayer_top",
                                    frame: CGRect(x: 0, y: 0, width: bounds.width, height: thickness),
                                    start: CGPoint(x: 0.5, y: 0.0),
                                    end: CGPoint(x: 0.5, y: 1.0))
        // Bottom rim
        let bottom = makeGradientLayer(name: "rimLayer_bottom",
                                       frame: CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness),
                                       start: CGPoint(x: 0.5, y: 1.0),
                                       end: CGPoint(x: 0.5, y: 0.0))
        // Left rim
        let left = makeGradientLayer(name: "rimLayer_left",
                                     frame: CGRect(x: 0, y: 0, width: thickness, height: bounds.height),
                                     start: CGPoint(x: 0.0, y: 0.5),
                                     end: CGPoint(x: 1.0, y: 0.5))
        // Right rim
        let right = makeGradientLayer(name: "rimLayer_right",
                                      frame: CGRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height),
                                      start: CGPoint(x: 1.0, y: 0.5),
                                      end: CGPoint(x: 0.0, y: 0.5))

        // Mask with rounded rect so the rims follow the corners
        let mask = CAShapeLayer()
        mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        mask.fillColor = UIColor.white.cgColor

        // Add layers above blur/tint but below content
        let container = CALayer()
        container.name = "rimLayer_container"
        container.frame = bounds
        container.masksToBounds = true
        container.cornerRadius = cornerRadius
        container.addSublayer(top)
        container.addSublayer(bottom)
        container.addSublayer(left)
        container.addSublayer(right)
        container.mask = mask

        // Insert just above existing sublayers that draw blur/tint/highlight
        layer.addSublayer(container)
    }
}

// MARK: - Interface Builder support (@IBInspectable)
@IBDesignable
extension UIView {
    @IBInspectable public var ibCornerRadius: CGFloat {
        get { layer.cornerRadius }
        set { layer.cornerRadius = newValue }
    }

    @IBInspectable public var ibMasksToBounds: Bool {
        get { layer.masksToBounds }
        set { layer.masksToBounds = newValue }
    }

    @IBInspectable public var ibBorderWidth: CGFloat {
        get { layer.borderWidth }
        set { layer.borderWidth = newValue }
    }

    @IBInspectable public var ibBorderColor: UIColor? {
        get {
            guard let cg = layer.borderColor else { return nil }
            return UIColor(cgColor: cg)
        }
        set { layer.borderColor = newValue?.cgColor }
    }

    @IBInspectable public var ibShadowColor: UIColor? {
        get {
            guard let cg = layer.shadowColor else { return nil }
            return UIColor(cgColor: cg)
        }
        set { layer.shadowColor = newValue?.cgColor }
    }

    @IBInspectable public var ibShadowOpacity: Float {
        get { layer.shadowOpacity }
        set { layer.shadowOpacity = newValue }
    }

    @IBInspectable public var ibShadowRadius: CGFloat {
        get { layer.shadowRadius }
        set { layer.shadowRadius = newValue }
    }

    @IBInspectable public var ibShadowOffsetWidth: CGFloat {
        get { layer.shadowOffset.width }
        set { layer.shadowOffset = CGSize(width: newValue, height: layer.shadowOffset.height) }
    }

    @IBInspectable public var ibShadowOffsetHeight: CGFloat {
        get { layer.shadowOffset.height }
        set { layer.shadowOffset = CGSize(width: layer.shadowOffset.width, height: newValue) }
    }
}

// MARK: - GradientHighlightView
/// Private UIView subclass used by applyGlassEffect to host the top highlight gradient.
/// Overrides layoutSubviews so the CAGradientLayer frame stays in sync with the view's
/// bounds on every layout pass (rotation, dynamic type, split-screen, etc.).
private final class GradientHighlightView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        layer.addSublayer(gradientLayer)
    }

    func updateColors(top: UIColor, bottom: UIColor) {
        gradientLayer.colors = [top.cgColor, bottom.cgColor]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep the gradient frame in sync with bounds on every layout pass
        gradientLayer.frame = bounds
    }
}
