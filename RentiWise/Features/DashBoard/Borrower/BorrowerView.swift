//
//  BorrowerView.swift
//  RentiWise
//
//  Created by admin99 on 10/11/25.
//

import UIKit

protocol BorrowerViewDelegate: AnyObject {
    func borrowerViewDidTapViewBlue(_ borrowerView: BorrowerView)
}

class BorrowerView: UIView {

    @IBOutlet weak var viewblue: UIView!
    weak var delegate: BorrowerViewDelegate?
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
            
            viewblue?.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapViewBlue))
            viewblue?.addGestureRecognizer(tap)
            viewblue?.isAccessibilityElement = true
            viewblue?.accessibilityTraits = .button
            viewblue?.accessibilityLabel = "Booking approval"
        }
    
    @objc private func didTapViewBlue() {
        UISelectionFeedbackGenerator().selectionChanged()
        delegate?.borrowerViewDidTapViewBlue(self)
    }

}
