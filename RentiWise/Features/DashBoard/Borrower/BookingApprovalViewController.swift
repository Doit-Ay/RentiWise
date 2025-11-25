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
    override func viewDidLoad() {
        super.viewDidLoad()
        circ1.layer.cornerRadius = circ1.bounds.height / 2
        circ1.layer.masksToBounds = true
        circ2.layer.cornerRadius = circ2.bounds.height / 2
        circ2.layer.masksToBounds = true
        circ3.layer.cornerRadius = circ3.bounds.height / 2
        circ3.layer.masksToBounds = true
        // Do any additional setup after loading the view.
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
