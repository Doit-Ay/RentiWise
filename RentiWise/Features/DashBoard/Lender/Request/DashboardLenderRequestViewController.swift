//
//  DashboardLenderRequestViewController.swift
//  ProductDetails
//
//  Created by user@48 on 20/11/25.
//

import UIKit
import Supabase

// Match the Variant 1 model used in LenderView (requests + items join only)
struct RequestWithItem: Decodable {
    let id: String
    let item_id: String
    let owner_id: String
    let borrower_id: String
    let start_date: String   // "yyyy-MM-dd" from DB
    let end_date: String     // "yyyy-MM-dd" from DB
    let pickup_time: String?
    var status: String
    let created_at: String?

    let items: ItemLite? // joined item
}

struct ItemLite: Decodable {
    let id: String
    let title: String
    let images: [String]
    let price_per_day: Double
}

class DashboardLenderRequestViewController: UIViewController {

    // Inject this before pushing
    var request: RequestWithItem? {
        didSet {
            // If the view is loaded, apply immediately on main thread
            if isViewLoaded {
                DispatchQueue.main.async { [weak self] in
                    self?.applyRequestToUI()
                }
            }
        }
    }

    @IBOutlet weak var bluecard: UIView!
    @IBOutlet weak var whitecard: UIView!
    @IBOutlet weak var prodimage: UIImageView!
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var Bookingcard: UIView!
    @IBOutlet weak var datelabel: UILabel!
    @IBOutlet weak var numberodDaysLabel: UILabel!
    @IBOutlet weak var pickuptimeLabel: UILabel!
    @IBOutlet weak var ownCard: UIView!
    @IBOutlet weak var initial: UIImageView!
    @IBOutlet weak var ownNameLabel: UILabel!
    @IBOutlet weak var ownRatingLabel: UILabel!
    @IBOutlet weak var ownDistLabel: UILabel!
    @IBOutlet weak var priceCard: UIView!
    @IBOutlet weak var feerentLabel: UILabel!
    @IBOutlet weak var secRateLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var denyButton: UIButton!

    private let displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone.current
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    private let sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Details"

        // Style deny button border color to #5DA9B6
        denyButton?.layer.borderWidth = 1
        denyButton?.layer.cornerRadius = 12
        denyButton?.layer.masksToBounds = true
        denyButton?.layer.borderColor = UIColor(hex: "5DA9B6").cgColor

        // Basic defaults
        prodimage?.image = UIImage(systemName: "photo")
        prodimage?.tintColor = .secondaryLabel
        prodimage?.contentMode = .scaleAspectFit

        applyRequestToUI()
    }

    private func applyRequestToUI() {
        guard let req = request else {
            itemNameLabel?.text = ""
            categoryLabel?.text = ""
            datelabel?.text = ""
            numberodDaysLabel?.text = ""
            pickuptimeLabel?.text = ""
            ownNameLabel?.text = ""
            ownRatingLabel?.text = ""
            ownDistLabel?.text = ""
            feerentLabel?.text = ""
            secRateLabel?.text = ""
            totalLabel?.text = ""
            return
        }

        // Title from joined item, fallback to item_id
        itemNameLabel?.text = req.items?.title ?? req.item_id

        // Category not present in RequestWithItem; leave blank or fetch if you need it
        categoryLabel?.text = ""

        // Dates and duration
        let startDate = sqlDateFormatter.date(from: req.start_date)
        let endDate = sqlDateFormatter.date(from: req.end_date)

        if let s = startDate, let e = endDate {
            datelabel?.text = "\(displayDateFormatter.string(from: s)) — \(displayDateFormatter.string(from: e))"
            let days = max(1, Int(ceil(e.timeIntervalSince(s) / 86400.0)))
            numberodDaysLabel?.text = "\(days) day\(days == 1 ? "" : "s")"
        } else {
            datelabel?.text = "—"
            numberodDaysLabel?.text = "—"
        }

        // Pickup time raw for now
        if let t = req.pickup_time, !t.isEmpty {
            pickuptimeLabel?.text = t
        } else {
            pickuptimeLabel?.text = "—"
        }

        // Price per day from joined item
        if let p = req.items?.price_per_day {
            let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
            feerentLabel?.text = text
        } else {
            feerentLabel?.text = ""
        }

        // Security/total not part of requests schema; display status here for now
        totalLabel?.text = req.status.capitalized

        // Image from joined item
        if let path = req.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    self?.prodimage?.image = img
                    self?.prodimage?.contentMode = .scaleAspectFill
                    self?.prodimage?.clipsToBounds = true
                }
            }
        } else {
            prodimage?.image = UIImage(systemName: "photo")
            prodimage?.tintColor = .secondaryLabel
            prodimage?.contentMode = .scaleAspectFit
        }

        // Owner placeholders (fill later if needed)
        ownNameLabel?.text = "Owner"
        ownRatingLabel?.text = "★ 4.7"
        ownDistLabel?.text = "2.3 km"
    }

    // MARK: - Actions: Accept / Deny

    @IBAction func acceptbuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "accepted") }
    }

    @IBAction func denybuttontapped(_ sender: UIButton) {
        Task { await updateStatus(to: "denied") }
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        view.isUserInteractionEnabled = enabled
        denyButton?.alpha = enabled ? 1.0 : 0.6
    }

    private func updateStatus(to newStatus: String) async {
        guard var current = request else { return }
        await MainActor.run { self.setButtonsEnabled(false) }
        do {
            // PATCH requests set status = newStatus where id = current.id
            struct Patch: Encodable { let status: String }
            _ = try await SupabaseManager.shared.client
                .from("requests")
                .update(Patch(status: newStatus))
                .eq("id", value: current.id)
                .execute()

            // Update local model and UI
            current.status = newStatus
            self.request = current

            await MainActor.run {
                self.totalLabel?.text = newStatus.capitalized
            }

            // Tell LenderView to refresh Requests
            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)

            // Navigate back to Dashboard → Lender → Requests
            await MainActor.run {
                // If presented modally, dismiss; else pop
                if let presenting = self.presentingViewController, self.navigationController == nil {
                    self.dismiss(animated: true) {
                        // No-op; Dashboard should handle showing correct segment
                    }
                } else if let nav = self.navigationController {
                    nav.popViewController(animated: true)
                }
            }
        } catch {
            await MainActor.run {
                let alert = UIAlertController(title: "Update Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        await MainActor.run { self.setButtonsEnabled(true) }
    }
}
