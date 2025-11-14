//
//  UIExtension.swift
//  RentiWise
//
//  Created by admin99 on 14/11/25.
//

import UIKit

// MARK: - UIView styling helpers (programmatic)
extension UIView {

    /// Apply corner radius and optional border.
    /// - Parameters:
    ///   - cornerRadius: Corner radius (default 12).
    ///   - masksToBounds: Whether to clip sublayers to bounds. Use true when you want content clipped; false if you plan to add shadow on this same layer. Default false.
    ///   - borderWidth: Border width (default 0 = none).
    ///   - borderColor: Border color (default nil = none).
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

    /// Apply a drop shadow to the view's layer.
    /// Note: For shadows to be visible, layer.masksToBounds must be false.
    /// If you also need rounded, clipped content, put that content inside a rounded subview and keep this outer view unmasked.
    /// - Parameters:
    ///   - color: Shadow color (default black).
    ///   - opacity: Shadow opacity 0.0–1.0 (default 0.2).
    ///   - radius: Shadow blur radius (default 6).
    ///   - offset: Shadow offset (default .init(width: 0, height: 3)).
    ///   - shouldRasterize: If true, rasterizes the shadow for performance on static views (default false).
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

        // Optional: rasterize for performance if the view won't animate/resize frequently
        layer.shouldRasterize = shouldRasterize
        layer.rasterizationScale = UIScreen.main.scale
    }

    /// Convenience to apply both rounded corners/border and shadow in a common pattern.
    /// This keeps the shadow visible (outer layer) and clips content inside an inner container if needed.
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the inner content container.
    ///   - borderWidth: Border width on the inner content container.
    ///   - borderColor: Border color on the inner content container.
    ///   - shadowColor: Shadow color for the outer layer.
    ///   - shadowOpacity: Shadow opacity.
    ///   - shadowRadius: Shadow blur radius.
    ///   - shadowOffset: Shadow offset.
    /// - Returns: The inner container view you can add content into, already constrained to fill self.
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
        // Ensure the outer view draws the shadow
        applyShadow(color: shadowColor,
                    opacity: shadowOpacity,
                    radius: shadowRadius,
                    offset: shadowOffset)

        // Create an inner container that clips content to rounded corners and border
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
