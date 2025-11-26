//
//  LenderRequestTableViewCell.swift
//  RentiWise
//
//  Created by admin99 on 20/11/25.
//

import UIKit

final class LenderRequestTableViewCell: UITableViewCell {

    @IBOutlet weak var itemImageRequest: UIImageView!
    @IBOutlet weak var itemNameRequest: UILabel!
    @IBOutlet weak var itemRateRequest: UILabel!
    @IBOutlet weak var itemBorrowerRequest: UILabel!

    // If you later add image loading, keep a task to cancel on reuse
    private var imageLoadTask: URLSessionDataTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        // Optional styling
        itemImageRequest?.contentMode = .scaleAspectFill
        itemImageRequest?.clipsToBounds = true
        itemImageRequest?.layer.cornerRadius = 8
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        itemImageRequest?.image = nil
        itemNameRequest?.text = nil
        itemRateRequest?.text = nil
        itemBorrowerRequest?.text = nil
    }

    // MARK: - Configure with public.requests row
    // Use this once LenderView switches to public.requests and decodes RequestsRow
    struct RequestsRowViewModel {
        let itemId: String
        let status: String
        let startDate: Date?
        let endDate: Date?
        let pickupTime: String?
        // Optional future fields: title, thumbnailURL
    }

    func configure(with vm: RequestsRowViewModel) {
        // Title placeholder: show item_id until you join items to get title
        itemNameRequest?.text = vm.itemId

        // Status
        itemBorrowerRequest?.text = vm.status.capitalized

        // Date range label (was itemRateRequest label in your XIB; repurpose for now)
        if let start = vm.startDate, let end = vm.endDate {
            let df = DateFormatter()
            df.dateFormat = "d MMM yyyy"
            let range = "\(df.string(from: start)) — \(df.string(from: end))"
            itemRateRequest?.text = range
        } else {
            // If parsing fails, fall back to raw values or a dash
            itemRateRequest?.text = "—"
        }

        // Image: leave empty for now; when you join items, set itemImageRequest
        itemImageRequest?.image = UIImage(systemName: "photo")
        itemImageRequest?.tintColor = .secondaryLabel
        itemImageRequest?.contentMode = .scaleAspectFit
    }

    // Optional helper for future when you pass a thumbnail URL
    func setImage(from url: URL) {
        // Cancel any previous load
        imageLoadTask?.cancel()

        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        imageLoadTask = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.itemImageRequest?.image = img
                self.itemImageRequest?.contentMode = .scaleAspectFill
            }
        }
        imageLoadTask?.resume()
    }
}
