//
//  UISearchBar+Styling.swift
//  RentiWise
//
//  Created by admin99 on 2026-02-05.
//

import UIKit

extension UISearchBar {
    
    /// Applies consistent native iOS search bar styling
    func applyRentiWiseStyle() {
        // Brand teal color
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        
        // Native clean iOS appearance
        searchBarStyle = .minimal
        tintColor = brandTeal
        isTranslucent = true
        backgroundColor = .clear
        backgroundImage = UIImage()
        setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        
        // Ensure standard textfield properties are retained
        let tf = searchTextField
        tf.textColor = .label
        tf.tintColor = brandTeal
        tf.clearButtonMode = .whileEditing
        tf.leftView?.tintColor = .tertiaryLabel
        
        // Reset any layer manipulations to allow standard system drawing
        tf.layer.shadowOpacity = 0
        tf.layer.borderWidth = 0
        tf.layer.cornerRadius = 10
        tf.layer.masksToBounds = true
    }
    
    /// Stubbed out to ensure standard corner radious is not overridden
    func applyRoundedCorners() {
        // No-op: Native search bars handle their own corner radius
    }
}
