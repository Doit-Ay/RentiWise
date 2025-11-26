//
//  BookingApprovalViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit

class BookingApprovalViewController: UIViewController {

    @IBOutlet weak var outerblueCard: UIView!
    @IBOutlet weak var inneRCard: UIView!
    @IBOutlet weak var imageprod: UIImageView!
    @IBOutlet weak var nameofitemLabel: UILabel!
    @IBOutlet weak var categoryitemLabel: UILabel!
    
    @IBOutlet weak var statusView: UIView!

    @IBOutlet weak var circ1: UIView!
    @IBOutlet weak var circ2: UIView!
    @IBOutlet weak var circ3: UIView!

    // New container that holds ONLY the "View Code" button and the stack
    @IBOutlet weak var viewCodeUIView: UIView!
    @IBOutlet weak var codestack: UIStackView!

    // Code digit views
    @IBOutlet weak var c1view: UIView!
    @IBOutlet weak var code1Label: UILabel!
    @IBOutlet weak var c2view: UIView!
    @IBOutlet weak var code2Label: UILabel!
    @IBOutlet weak var c3view: UIView!
    @IBOutlet weak var code3Label: UILabel!
    @IBOutlet weak var c4view: UIView!
    @IBOutlet weak var code4Label: UILabel!
    @IBOutlet weak var c5view: UIView!
    @IBOutlet weak var code5Label: UILabel!
    @IBOutlet weak var c6view: UIView!
    @IBOutlet weak var code6Label: UILabel!

    // Height constraint for the new "View Code" container
    @IBOutlet weak var viewCodeHeight: NSLayoutConstraint!

    // Collapse/expand helpers
    private var codeStackCollapseConstraint: NSLayoutConstraint?

    // Heights
    private let collapsedViewCodeHeight: CGFloat = 56
    private let expandedViewCodeHeight: CGFloat = 140

    override func viewDidLoad() {
        super.viewDidLoad()

        // Round only top corners of statusView
        statusView.layer.cornerRadius = 20
        statusView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        statusView.layer.masksToBounds = true

        // Round only bottom corners of viewCodeUIView
        viewCodeUIView.layer.cornerRadius = 20
        viewCodeUIView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        viewCodeUIView.layer.masksToBounds = true

        // Circles
        circ1.layer.cornerRadius = circ1.bounds.height / 2
        circ1.layer.masksToBounds = true
        circ2.layer.cornerRadius = circ2.bounds.height / 2
        circ2.layer.masksToBounds = true
        circ3.layer.cornerRadius = circ3.bounds.height / 2
        circ3.layer.masksToBounds = true

        // Code digit boxes styling
        let codeViews: [UIView?] = [c1view, c2view, c3view, c4view, c5view, c6view]
        let borderColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0).cgColor
        codeViews.forEach { v in
            v?.layer.cornerRadius = 12
            v?.layer.borderWidth = 2
            v?.layer.borderColor = borderColor
            v?.layer.masksToBounds = true
        }

        // Prepare a reusable collapse constraint for the code stack
        if codeStackCollapseConstraint == nil {
            codeStackCollapseConstraint = codestack.heightAnchor.constraint(equalToConstant: 0)
        }

        // Start collapsed: show only the button, hide the stack
        codestack.isHidden = true
        codeStackCollapseConstraint?.isActive = true
        viewCodeHeight?.constant = collapsedViewCodeHeight
        viewCodeHeight?.isActive = true
    }

    @IBAction func ViewHideCodeButton(_ sender: UIButton) {
        let isCurrentlyShowingCode = (sender.title(for: .normal) ?? "") == "Hide Code"
        let shouldShowCode = !isCurrentlyShowingCode

        sender.setTitle(shouldShowCode ? "Hide Code" : "View Code", for: .normal)

        if shouldShowCode {
            // Expand the View Code container and reveal the stack
            codeStackCollapseConstraint?.isActive = false
            codestack.isHidden = false
            viewCodeHeight?.constant = expandedViewCodeHeight
            viewCodeHeight?.isActive = true
        } else {
            // Collapse to button-only and hide the stack
            codeStackCollapseConstraint?.isActive = true
            codestack.isHidden = true
            viewCodeHeight?.constant = collapsedViewCodeHeight
            viewCodeHeight?.isActive = true
        }

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func openChat() {
        let chatVC = ChatViewController(nibName: "ChatViewController", bundle: nil)
        if let nav = self.navigationController {
            nav.pushViewController(chatVC, animated: true)
        } else {
            chatVC.modalPresentationStyle = .fullScreen
            self.present(chatVC, animated: true)
        }
    }

    @IBAction func openChatButtonTapped(_ sender: Any) {
        openChat()
    }
}
