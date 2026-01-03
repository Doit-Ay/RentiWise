//
//  CategoryCollectionViewCell.swift
//  RentiWise
//
//  Created by admin99 on 06/11/25.
//

import UIKit

class CategoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var categoryImage: UIImageView!
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet weak var categoryBg: UIImageView!

    // A semi-transparent dark overlay to improve text contrast on photos
    private var darkOverlayView: UIView?

    override func awakeFromNib() {
        super.awakeFromNib()
        installDarkOverlayIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep overlay aligned to the bg image bounds
        if let bg = categoryBg, let overlay = darkOverlayView {
            overlay.frame = bg.bounds
        }
    }

    private func installDarkOverlayIfNeeded() {
        guard let bg = categoryBg else { return }
        // Avoid duplicates if nib reloads
        if darkOverlayView != nil { return }

        let overlay = UIView(frame: bg.bounds)
        overlay.isUserInteractionEnabled = false
        // Slightly dark; tweak between 0.22–0.35 as you like
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Insert above the image content but below label/icon
        bg.addSubview(overlay)
        darkOverlayView = overlay

        // Bring label and icon above overlay in case of z-order issues
        if let label = categoryLabel {
            contentView.bringSubviewToFront(label)
        }
        if let icon = categoryImage {
            contentView.bringSubviewToFront(icon)
        }
    }
}
