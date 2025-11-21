//
//  LenderRequestTableViewCell.swift
//  RentiWise
//
//  Created by admin99 on 20/11/25.
//

import UIKit

class LenderRequestTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBOutlet weak var itemImageRequest: UIImageView!
    
    @IBOutlet weak var itemNameRequest: UILabel!
    
    @IBOutlet weak var itemRateRequest: UILabel!
    
    @IBOutlet weak var itemBorrowerRequest: UILabel!
    
}
