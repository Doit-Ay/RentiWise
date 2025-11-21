//
//  LenderHistoryTableViewCell.swift
//  RentiWise
//
//  Created by admin99 on 20/11/25.
//

import UIKit

class LenderHistoryTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    @IBOutlet weak var itemImageHistory: UIImageView!
    
    @IBOutlet weak var itemNameHistory: UILabel!
    
    @IBOutlet weak var itemRateHistory: UILabel!
    
    @IBOutlet weak var itemBorrowerName: UILabel!
}
