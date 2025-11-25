//
//  EarningsOverviewViewController.swift
//  ProductDetails
//
//  Created by user@48 on 18/11/25.
//

import UIKit

class EarningsOverviewViewController: UIViewController {

    @IBOutlet weak var Thismonthview: UIView!
    @IBOutlet weak var EarningspermonthLabel: UILabel!
    @IBOutlet weak var totalEarningsView: UIView!
    @IBOutlet weak var totalEarningsLabel: UILabel!
    @IBOutlet weak var availableBalanceLabel: UILabel!
    @IBOutlet weak var pendingBalanceLabel: UILabel!
    @IBOutlet weak var balanceCard: UIView!
    @IBOutlet weak var transactionCard: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        title = "Earnings Overview"
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

