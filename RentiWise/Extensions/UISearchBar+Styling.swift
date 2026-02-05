//
//  UISearchBar+Styling.swift
//  RentiWise
//
//  Created by admin99 on 2026-02-05.
//

import UIKit

extension UISearchBar {
    
    /// Applies consistent RentiWise search bar styling
    func applyRentiWiseStyle() {
        // Brand teal color
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        
        // Base config
        searchBarStyle = .minimal
        isTranslucent = true
        backgroundColor = .clear
        setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        setSearchFieldBackgroundImage(UIImage(), for: .normal)
        tintColor = brandTeal
        
        // Text field styling (iOS 13+)
        let tf = searchTextField
        tf.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        tf.textColor = .label
        tf.tintColor = brandTeal
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .none
        tf.layer.masksToBounds = false
        tf.leftView?.tintColor = .tertiaryLabel
        
        // Placeholder with subtle color
        let placeholder = tf.placeholder ?? "Search"
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        
        // Shadow to lift the pill
        tf.layer.shadowColor = UIColor.black.cgColor
        tf.layer.shadowOpacity = 0.08
        tf.layer.shadowRadius = 6
        tf.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        // Apply rounded corners
        applyRoundedCorners()
    }
    
    /// Applies pill-shaped rounded corners to the search field
    func applyRoundedCorners() {
        let tf = searchTextField
        let h = tf.bounds.height > 0 ? tf.bounds.height : 36
        tf.layer.cornerRadius = h / 2
        tf.layer.borderWidth = 0.5
        tf.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
    }
}
