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
    @IBOutlet weak var itemcardview: UIView!
    // If you later add image loading, keep a task to cancel on reuse
    private var imageLoadTask: URLSessionDataTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        // Match Categories: make the cell itself transparent so the table’s grouped background shows
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        // Image styling
        itemImageRequest?.contentMode = .scaleAspectFill
        itemImageRequest?.clipsToBounds = true
        itemImageRequest?.layer.cornerRadius = 12

        // Card setup: clear background; glass effect supplies the surface/shadow
        itemcardview?.layer.cornerRadius = 16
        itemcardview?.layer.masksToBounds = false
        itemcardview?.backgroundColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Strong, clean glass like CategoryItemCell, with a bit more contrast on grouped bg
        itemcardview?.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.30,
            tintColorOverride: .white,
            tintAlpha: 0.18,     // slightly stronger than default for definition
            showsHighlight: true,
            highlightAlpha: 0.16 // subtle specular highlight
        )
        // Slightly softer shadow like your category cards
        itemcardview?.layer.shadowOpacity = 0.12
        itemcardview?.layer.shadowRadius = 8
        itemcardview?.layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        itemImageRequest?.image = nil
        itemNameRequest?.text = nil
        itemRateRequest?.text = nil
        itemBorrowerRequest?.text = nil

        // Keep backgrounds consistent
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        itemcardview?.backgroundColor = .clear
    }

    // MARK: - Configure with public.requests row
    struct RequestsRowViewModel {
        let itemId: String
        let status: String
        let startDate: Date?
        let endDate: Date?
        let pickupTime: String?
    }

    func configure(with vm: RequestsRowViewModel) {
        itemNameRequest?.text = vm.itemId
        itemBorrowerRequest?.text = vm.status.capitalized

        if let start = vm.startDate, let end = vm.endDate {
            let df = DateFormatter()
            df.dateFormat = "d MMM yyyy"
            itemRateRequest?.text = "\(df.string(from: start)) — \(df.string(from: end))"
        } else {
            itemRateRequest?.text = "—"
        }

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

