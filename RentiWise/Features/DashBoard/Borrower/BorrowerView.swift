//
//  BorrowerView.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

class BorrowerView: UIView {

    override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        private func commonInit() {
            let nib = UINib(nibName: "BorrowerView", bundle: nil)
            guard let view = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
            view.frame = bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(view)
        }

}
