//
//  ChatViewController.swift
//  ProductDetails
//
//  Created by user@48 on 25/11/25.
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
        // Do any additional setup after loading the view.
        
        // Style chat UI elements
        let cornerRadius: CGFloat = 12
        datechatview?.layer.cornerRadius = cornerRadius
        lender1View?.layer.cornerRadius = cornerRadius
        lender2View?.layer.cornerRadius = cornerRadius
        borrower1View?.layer.cornerRadius = cornerRadius
        borrower2View?.layer.cornerRadius = cornerRadius
        chattextField?.layer.cornerRadius = cornerRadius
        
        // Add border to lender views
        let borderColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0).cgColor
        lender1View?.layer.borderWidth = 1
        lender1View?.layer.borderColor = borderColor
        lender2View?.layer.borderWidth = 1
        lender2View?.layer.borderColor = borderColor
        
        // Ensure sublayers are clipped to bounds for rounded corners
        datechatview?.layer.masksToBounds = true
        lender1View?.layer.masksToBounds = true
        lender2View?.layer.masksToBounds = true
        borrower1View?.layer.masksToBounds = true
        borrower2View?.layer.masksToBounds = true
        chattextField?.layer.masksToBounds = true
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
