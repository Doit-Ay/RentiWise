//
//  ProductVeiwController.swift
//  ProductDetails
//
//  Created by user@48 on 13/11/25.
//

import UIKit

final class ProductViewController: UIViewController {
    @IBOutlet weak var heroImageView: UIImageView!

    @IBOutlet weak var priceLabel: UILabel?
    @IBOutlet weak var distanceLabel: UILabel?
    @IBOutlet weak var ratingValueLabel: UILabel?
    @IBOutlet weak var ratingReviewsLabel: UILabel?

    // MARK: - Description card
    @IBOutlet weak var descriptionCard: UIView!
    @IBOutlet weak var descriptionTitleLabel: UILabel!
    @IBOutlet weak var descriptionBodyLabel: UILabel!

    // MARK: - Owner card
    @IBOutlet weak var ownerCard: UIView!
    @IBOutlet weak var ownerAvatarImageView: UIImageView!
    @IBOutlet weak var ownerNameLabel: UILabel!
    @IBOutlet weak var distanceRightLabel: UILabel!

    // MARK: - Deposit card
    @IBOutlet weak var depositCard: UIView!
    @IBOutlet weak var depositTitleLabel: UILabel!
    @IBOutlet weak var depositBodyLabel: UILabel!

    // MARK: - Reviews section (two sample reviews)
    @IBOutlet weak var reviewsTitleLabel: UILabel?

    // Review 1 (Alex K.)
    @IBOutlet weak var review1Card: UIView?
    @IBOutlet weak var review1DateLabel: UILabel?
    @IBOutlet weak var r1star1: UIImageView?
    @IBOutlet weak var r1star2: UIImageView?
    @IBOutlet weak var r1star3: UIImageView?
    @IBOutlet weak var r1star4: UIImageView?
    @IBOutlet weak var r1star5: UIImageView?
    @IBOutlet weak var r1AvatarImageView: UIImageView?
    @IBOutlet weak var r1NameLabel: UILabel?
    @IBOutlet weak var r1CommentLabel: UILabel?

    // Review 2 (Emily R.)
    @IBOutlet weak var review2Card: UIView?
    @IBOutlet weak var review2DateLabel: UILabel?
    @IBOutlet weak var r2star1: UIImageView?
    @IBOutlet weak var r2star2: UIImageView?
    @IBOutlet weak var r2star3: UIImageView?
    @IBOutlet weak var r2star4: UIImageView?
    @IBOutlet weak var r2star5: UIImageView?
    @IBOutlet weak var r2AvatarImageView: UIImageView?
    @IBOutlet weak var r2NameLabel: UILabel?
    @IBOutlet weak var r2CommentLabel: UILabel?


    // optional actions (hook later when screens exist)
    @IBAction func didTapWriteReview(_ sender: UIButton) {
        let nibName = "WriteReviewViewController"
        let writeVC: WriteReviewViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            writeVC = WriteReviewViewController(nibName: nibName, bundle: nil)
        } else {
            writeVC = WriteReviewViewController()
        }

        if let nav = self.navigationController {
            nav.pushViewController(writeVC, animated: true)
        } else {
            if let popover = writeVC.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            writeVC.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad ? .formSheet : .pageSheet
            self.present(writeVC, animated: true)
        }
    }

    @IBAction func didTapRentNow(_ sender: UIButton) {
        // Hook to push/present RentNow screen later
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Product Detail"
    }
}
