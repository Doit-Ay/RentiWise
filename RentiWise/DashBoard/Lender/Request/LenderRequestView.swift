//
//  LenderRequestView.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

class LenderRequestView: UIView {

    // Connect this to the top-level view in LenderRequestView.xib (File’s Owner -> view)
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
        if view != nil, view.isDescendant(of: self) {
            return
        }

        Bundle.main.loadNibNamed("LenderRequestView", owner: self, options: nil)

        guard let content = view else {
            assertionFailure("LenderRequestView.xib not loaded or 'view' outlet not connected to top-level view. Check: File's Owner = LenderRequestView, top view = UIView, and connect File's Owner 'view' -> top view.")
            return
        }

        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)
    }

}
