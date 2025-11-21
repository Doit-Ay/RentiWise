//
//  RequestViewController.swift
//  ProductDetails
//
//  Created by user@48 on 14/11/25.
//

import UIKit

class RequestViewController: UIViewController {
    @IBOutlet weak var productCardView: UIView!
    @IBOutlet weak var productThumbImageView: UIImageView!
    @IBOutlet weak var productTitleLabel: UILabel!
    @IBOutlet weak var productRateLabel: UILabel!
    @IBOutlet weak var productRatingLabel: UILabel!
    @IBOutlet weak var rentalTypeCard: UIView!
    @IBOutlet weak var rentalTypeTitleLabel: UILabel!
    @IBOutlet weak var productDistance: UILabel!
    @IBOutlet weak var rentalOptionsStack: UIStackView!
    @IBOutlet weak var hourButton: UIButton!
    @IBOutlet weak var dayButton: UIButton!
    @IBOutlet weak var selectdateandtimeCard: UIView!
    @IBOutlet weak var selectdateandtimeLabel: UILabel!
    @IBOutlet weak var dateLabel: UIDatePicker!
    @IBOutlet weak var pickuptimeLabel: UIDatePicker!
    @IBOutlet weak var returntimeLabel: UIDatePicker!
    @IBOutlet weak var bookingsummaryCard: UIView!
    @IBOutlet weak var bookingsummaryLabel: UILabel!
    @IBOutlet weak var label1sum: UILabel!
    @IBOutlet weak var label2sum: UILabel!
    @IBOutlet weak var label3sum: UILabel!
    @IBOutlet weak var ownerCard: UIView!
    @IBOutlet weak var ownerDist: UILabel!
    @IBOutlet weak var ownerRating: UILabel!
    @IBOutlet weak var ownerName: UILabel!
    @IBOutlet weak var ownerImage: UIImageView!
    @IBOutlet weak var priceBreakdownCard: UIView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var rentalfee: UILabel!
    @IBOutlet weak var totalamount: UILabel!
    @IBOutlet weak var secRate: UILabel!
    @IBOutlet weak var fee: UILabel!
    @IBOutlet weak var security: UILabel!
    @IBOutlet weak var total: UILabel!
    @IBOutlet weak var boookingcontainer: UIView?
    
    @IBOutlet weak var dateTitleLabel: UILabel!
    @IBOutlet weak var returnTimeTitleLabel: UILabel!
    
    private enum RentalSelection { case none, hour, day }
    private var currentSelection: RentalSelection = .none
    
    private enum Mode { case perHour, perDay }
    private var mode: Mode { currentSelection == .day ? .perDay : .perHour }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Request"
        view.backgroundColor = .systemBackground

        productCardView?.layer.cornerRadius = 12
        productCardView?.layer.masksToBounds = true

        [rentalTypeCard, selectdateandtimeCard, bookingsummaryCard, ownerCard, priceBreakdownCard].forEach {
            $0?.layer.cornerRadius = 12
            $0?.layer.masksToBounds = true
        }

        setupOptionButtons()
        boookingcontainer?.isHidden = true
        
        if let hourButton = hourButton { set(button: hourButton, selected: false) }
        if let dayButton = dayButton { set(button: dayButton, selected: false) }
        
        dateLabel?.addTarget(self, action: #selector(dateDidChange(_:)), for: .valueChanged)
        pickuptimeLabel?.addTarget(self, action: #selector(pickupDidChange(_:)), for: .valueChanged)
        returntimeLabel?.addTarget(self, action: #selector(returnDidChange(_:)), for: .valueChanged)
        
        dateLabel?.datePickerMode = .date
        pickuptimeLabel?.datePickerMode = .time
        returntimeLabel?.datePickerMode = .time

        if let datePicker = dateLabel, let pickup = pickuptimeLabel, let drop = returntimeLabel {
            let now = Date()
            datePicker.date = now
            pickup.date = now
            drop.date = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
            drop.minimumDate = datePicker.date
        }

        // Initialize titles for the default mode (per-hour until selection)
        applyTitlesForCurrentMode()
        updateUIForMode()
        
        label1sum?.text = ""
        label2sum?.text = ""
        label3sum?.text = ""
    }
    
    private func setupOptionButtons() {
        styleOptionButton(hourButton)
        styleOptionButton(dayButton)
    }

    private func styleOptionButton(_ button: UIButton?) {
        guard let button = button else { return }
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.layer.masksToBounds = true
        button.backgroundColor = .white
    }
    
    private func set(button: UIButton, selected: Bool) {
        let selectedColor = UIColor(hex: "5DA9B6").cgColor
        let normalColor = UIColor.systemGray4.cgColor
        button.layer.borderColor = selected ? selectedColor : normalColor
        button.backgroundColor = .white
    }

    @IBAction func didTapHour(_ sender: UIButton) {
        if currentSelection == .hour {
            currentSelection = .none
            boookingcontainer?.isHidden = true
            if let hourButton = hourButton { set(button: hourButton, selected: false) }
            if let dayButton = dayButton { set(button: dayButton, selected: false) }
            label1sum?.text = ""
            label2sum?.text = ""
            label3sum?.text = ""
        } else {
            currentSelection = .hour
            boookingcontainer?.isHidden = false
            
            if let hourButton = hourButton { set(button: hourButton, selected: true) }
            if let dayButton = dayButton { set(button: dayButton, selected: false) }

            dateLabel?.datePickerMode = .date
            pickuptimeLabel?.datePickerMode = .time
            returntimeLabel?.datePickerMode = .time

            // Per-hour titles and accessibility
            dateTitleLabel?.text = "Date"
            returnTimeTitleLabel?.text = "Return Time"
            dateLabel?.accessibilityLabel = "Date"
            returntimeLabel?.accessibilityLabel = "Return Time"
            pickuptimeLabel?.accessibilityLabel = "Pickup Time"

            if let pickup = pickuptimeLabel, let drop = returntimeLabel {
                if drop.date <= pickup.date {
                    drop.date = Calendar.current.date(byAdding: .hour, value: 1, to: pickup.date) ?? pickup.date
                }
            }
            updateUIForMode()
        }
    }

    @IBAction func didTapDay(_ sender: UIButton) {
        if currentSelection == .day {
            currentSelection = .none
            boookingcontainer?.isHidden = true
            if let hourButton = hourButton { set(button: hourButton, selected: false) }
            if let dayButton = dayButton { set(button: dayButton, selected: false) }
            // Revert titles to neutral when clearing
            dateTitleLabel?.text = "Date"
            returnTimeTitleLabel?.text = "Return Time"
            label1sum?.text = ""
            label2sum?.text = ""
            label3sum?.text = ""
        } else {
            currentSelection = .day
            boookingcontainer?.isHidden = false
            
            if let hourButton = hourButton { set(button: hourButton, selected: false) }
            if let dayButton = dayButton { set(button: dayButton, selected: true) }

            // Per-day mode configuration:
            // dateLabel -> Pickup Date, returntimeLabel -> Return Date, pickuptimeLabel -> Pickup Time
            dateLabel?.datePickerMode = .date
            pickuptimeLabel?.datePickerMode = .time
            returntimeLabel?.datePickerMode = .date

            // Update visible titles
            dateTitleLabel?.text = "Pickup Date"
            returnTimeTitleLabel?.text = "Return Date"

            // Accessibility
            dateLabel?.accessibilityLabel = "Pickup Date"
            returntimeLabel?.accessibilityLabel = "Return Date"
            pickuptimeLabel?.accessibilityLabel = "Pickup Time"

            if let pickupDatePicker = dateLabel, let returnDatePicker = returntimeLabel {
                let startOfPickup = Calendar.current.startOfDay(for: pickupDatePicker.date)
                returnDatePicker.minimumDate = startOfPickup
                if returnDatePicker.date < startOfPickup {
                    returnDatePicker.date = startOfPickup
                }
            }
            updateUIForMode()
        }
    }
    @IBAction func requestRentalclicked(_ sender: UIButton) {
        // Try storyboard first with concrete type
        if let storyboard = self.storyboard,
           let vc = storyboard.instantiateViewController(withIdentifier: "RequestSentPageViewController") as? RequestSentPageViewController {
            navigate(to: vc)
            return
        }

        // Fallback: attempt to resolve class by name and init
        let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let fullName = bundleName + ".RequestSentPageViewController"
        if let vcType = NSClassFromString(fullName) as? UIViewController.Type {
            let vc = vcType.init()
            navigate(to: vc)
            return
        }

        // Last resort: direct initializer
        let vc = RequestSentPageViewController()
        navigate(to: vc)
    }
    
    private func navigate(to destinationVC: UIViewController) {
        if let nav = self.navigationController {
            nav.pushViewController(destinationVC, animated: true)
        } else {
            destinationVC.modalPresentationStyle = .fullScreen
            self.present(destinationVC, animated: true, completion: nil)
        }
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        // Short month like "17 Nov 2025"
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    private lazy var timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
    
    private func refreshSummaryLabels() {
        guard let datePicker = dateLabel,
              let pickup = pickuptimeLabel,
              let drop = returntimeLabel else { return }
        let date = datePicker.date
        let pickupDate = pickup.date
        let dropDate = drop.date
        label1sum?.text = dateFormatter.string(from: date)
        label2sum?.text = "\(timeFormatter.string(from: pickupDate)) - \(timeFormatter.string(from: dropDate))"
        let seconds = dropDate.timeIntervalSince(pickupDate)
        if seconds > 0 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            if hours > 0 && minutes > 0 {
                label3sum?.text = "\(hours)h \(minutes)m"
            } else if hours > 0 {
                label3sum?.text = "\(hours)h"
            } else {
                label3sum?.text = "\(minutes)m"
            }
        } else {
            label3sum?.text = "0m"
        }
    }
    
    private func refreshPerDaySummaryLabels() {
        guard let pickupDatePicker = dateLabel,
              let returnDatePicker = returntimeLabel,
              let pickupTimePicker = pickuptimeLabel else { return }
        enforcePerDayConstraints()
        let startDate = pickupDatePicker.date
        let endDate = returnDatePicker.date
        let pickupTime = pickupTimePicker.date
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let comps = calendar.dateComponents([.day], from: startDay, to: endDay)
        let days = max(0, comps.day ?? 0) + 1

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        label1sum?.text = "\(startStr) - \(endStr)"
        label2sum?.text = timeFormatter.string(from: pickupTime)
        label3sum?.text = "\(days) day\(days == 1 ? "" : "s")"
    }
    
    private func updateUIForMode() {
        applyTitlesForCurrentMode()
        switch mode {
        case .perHour:
            refreshSummaryLabels()
        case .perDay:
            refreshPerDaySummaryLabels()
        }
    }
    
    private func applyTitlesForCurrentMode() {
        switch mode {
        case .perHour:
            dateTitleLabel?.text = "Date"
            returnTimeTitleLabel?.text = "Return Time"
        case .perDay:
            dateTitleLabel?.text = "Pickup Date"
            returnTimeTitleLabel?.text = "Return Date"
        }
    }
    
    @objc private func dateDidChange(_ sender: UIDatePicker) {
        updateUIForMode()
    }

    @objc private func pickupDidChange(_ sender: UIDatePicker) {
        updateUIForMode()
    }

    @objc private func returnDidChange(_ sender: UIDatePicker) {
        updateUIForMode()
    }
    
    private func enforcePerDayConstraints() {
        guard mode == .perDay, let pickupDatePicker = dateLabel, let returnDatePicker = returntimeLabel else { return }
        let startOfPickup = Calendar.current.startOfDay(for: pickupDatePicker.date)
        if returnDatePicker.date < startOfPickup {
            returnDatePicker.date = startOfPickup
        }
    }
}

// MARK: - Hex Color Helper
extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1.0
        )
    }
}
