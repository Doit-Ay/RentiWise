//
//  LenderListingView.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

class LenderListingView: UIView {

    // Connect this to the top-level view in LenderListingView.xib (File’s Owner -> view)
    @IBOutlet private(set) var view: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Prevent double-adding if somehow called twice
        if view != nil, view.isDescendant(of: self) {
            return
        }

        // Load the nib with File’s Owner pattern
        Bundle.main.loadNibNamed("LenderListingView", owner: self, options: nil)

        // Ensure the 'view' outlet is connected to the top-level view in the XIB
        guard let content = view else {
            assertionFailure("LenderListingView.xib not loaded or 'view' outlet not connected to top-level view. Check: File's Owner = LenderListingView, top view = UIView, and connect File's Owner 'view' -> top view.")
            return
        }

        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)
    }

}
