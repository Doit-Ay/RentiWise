//
//  ChatViewController.swift
//  ProductDetails
//
//  Created by user@48 on 25/11/25.
//
//  DEPRECATED: This is a legacy static XIB-based chat view from early prototyping.
//  The production chat interface is ChatThreadViewController in Features/DashBoard/Borrower.
//  This file is retained only for XIB compatibility — it redirects users to the real chat or
//  displays a placeholder message. It has no functional chat capabilities.
//

import UIKit

class ChatViewController: UIViewController {

    @IBOutlet weak var datechatview: UIView!
    @IBOutlet weak var lender1View: UIView!
    @IBOutlet weak var lender2View: UIView!
    @IBOutlet weak var borrower1View: UIView!
    @IBOutlet weak var borrower2View: UIView!
    @IBOutlet weak var chattextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat"

        // Hide all legacy static views — this view is deprecated
        datechatview?.isHidden = true
        lender1View?.isHidden = true
        lender2View?.isHidden = true
        borrower1View?.isHidden = true
        borrower2View?.isHidden = true
        chattextField?.isHidden = true

        // Show deprecation notice to user
        let notice = UILabel()
        notice.translatesAutoresizingMaskIntoConstraints = false
        notice.text = "This chat view is no longer available.\nPlease use the Chat button on the item listing."
        notice.textAlignment = .center
        notice.textColor = .secondaryLabel
        notice.font = .systemFont(ofSize: 15, weight: .regular)
        notice.numberOfLines = 0
        view.addSubview(notice)
        NSLayoutConstraint.activate([
            notice.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notice.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            notice.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            notice.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        // Auto-dismiss after a moment if presented modally
        if presentingViewController != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.dismiss(animated: true)
            }
        }
    }
}
