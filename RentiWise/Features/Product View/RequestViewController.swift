//
//  RequestViewController.swift
//  ProductDetails
//
//  Created by user@48 on 14/11/25.
//

import UIKit
import Supabase

@MainActor
class RequestViewController: UIViewController {
    // MARK: - IBOutlets
    
    @IBOutlet weak var itemcardview: UIView!
    //@IBOutlet weak var productCardView: UIView!
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
    
    // MARK: - Private Properties
    
    private var item: Item?
    private var itemId: String?

    public func configure(with item: Item) {
        self.item = item
        self.itemId = item.id
        applyItemToUI()
    }

    public func configure(withItemId id: String) {
        self.itemId = id
        loadItemIfNeeded()
    }
    
    private enum RentalUnit {
        case none
        case hour
        case day
    }
    
    private var rentalUnit: RentalUnit = .none
    
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    
    private var securityDeposit: Double = 0
    private let serviceFeeRate: Double = 0.10
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df
    }()
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
    
    private let selectedTeal = UIColor(hex: "5DA9B6")
    
    // Keep pickers' text color teal once user has made a selection; black only before selection
    private func updatePickerTextColors() {
        // We consider a picker "selected" if user interacted at least once.
        // UIDatePicker doesn't expose that directly, so we persist it via associated flags.
        let black: UIColor = .label
        dateLabel.setValue(hasSelectedDate ? selectedTeal : black, forKey: "textColor")
        pickuptimeLabel.setValue(hasSelectedPickupTime ? selectedTeal : black, forKey: "textColor")
        returntimeLabel.setValue(hasSelectedReturnTime ? selectedTeal : black, forKey: "textColor")
    }

    // Flags to remember if user selected each field at least once
    private var hasSelectedDate = false
    private var hasSelectedPickupTime = false
    private var hasSelectedReturnTime = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Request"
        navigationController?.setNavigationBarHidden(false, animated: false)
        view.backgroundColor = .systemGroupedBackground
        [rentalTypeCard, selectdateandtimeCard, bookingsummaryCard, ownerCard, priceBreakdownCard].forEach {
            $0?.layer.masksToBounds = true
        }
        // Ensure cards are white over the grouped background
        itemcardview?.backgroundColor = .white
        rentalTypeCard?.backgroundColor = .white
        selectdateandtimeCard?.backgroundColor = .white
        bookingsummaryCard?.backgroundColor = .white
        ownerCard?.backgroundColor = .white
        priceBreakdownCard?.backgroundColor = .white
        applyGlassToCards()
        dateLabel.datePickerMode = .date
        pickuptimeLabel.datePickerMode = .time
        returntimeLabel.datePickerMode = .time
        dateLabel.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
        pickuptimeLabel.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
        returntimeLabel.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
        
        // Initial text colors: black until user selects
        dateLabel.setValue(UIColor.label, forKey: "textColor")
        pickuptimeLabel.setValue(UIColor.label, forKey: "textColor")
        returntimeLabel.setValue(UIColor.label, forKey: "textColor")

        // Removed rentalUnit = .day
        
        updateRentalButtons()
        boookingcontainer?.isHidden = true

        // clear placeholders
        productTitleLabel?.text = nil
        productRateLabel?.text = nil
        productRatingLabel?.text = nil
        productDistance?.text = nil
        ownerName?.text = nil
        ownerRating?.text = nil
        ownerDist?.text = nil
        label1sum?.text = nil
        label2sum?.text = nil
        label3sum?.text = nil
        
        #if DEBUG
        if productTitleLabel == nil || productThumbImageView == nil || productRateLabel == nil {
            print("[RequestVC] Warning: One or more IBOutlets are not connected in Interface Builder.")
        }
        #endif
        
        if let _ = item {
            Task { await self.populateUI() }
        } else if itemId != nil {
            Task { await fetchItemIfNeeded() }
        }
    }

    // Applies the glass effect to all the primary card views.
    private func applyGlassToCards() {
        // Uses the simple glass extension defined in Glass.swift
        itemcardview?.applyGlassEffectSimple()
        rentalTypeCard?.applyGlassEffectSimple()
        selectdateandtimeCard?.applyGlassEffectSimple()
        bookingsummaryCard?.applyGlassEffectSimple()
        ownerCard?.applyGlassEffectSimple()
        priceBreakdownCard?.applyGlassEffectSimple()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if item == nil, itemId != nil {
            Task { await fetchItemIfNeeded() }
        } else {
            applyItemToUI()
            if rentalUnit != .none {
                recalculatePricing()
            }
        }
    }
    
    // MARK: - Data Fetching
    private func fetchItemIfNeeded() async {
        guard item == nil, let itemId = itemId else { return }
        do {
            let client = SupabaseManager.shared.client
            let response = try await client
                .from("items")
                .select("id,title,price_per_day,images,owner_id,deposit_amount")
                .eq("id", value: itemId)
                .single()
                .execute()
            
            if let data = response.data as? Data {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let fetched = try decoder.decode(Item.self, from: data)
                self.item = fetched
                await populateUI()
            } else {
                await MainActor.run { [weak self] in
                    self?.presentMissingItemAlert()
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.presentMissingItemAlert()
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func populateUI() async {
        guard let item = item else { return }
        applyItemToUI()
        await fetchAndDisplayOwnerProfile(for: item.owner_id)
        securityDeposit = item.deposit_amount
        recalculatePricing()
    }
    
    private func fetchAndDisplayOwnerProfile(for ownerId: String) async {
        struct ProfileDTO: Decodable {
            let full_name: String?
            let rating: Double?
            let distance_km: Double?
            let avatar_url: String?
        }
        
        do {
            let client = SupabaseManager.shared.client
            let response = try await client
                .from("profiles")
                .select("full_name,rating,distance_km,avatar_url")
                .eq("id", value: ownerId)
                .single()
                .execute()
            
            guard let data = response.data as? Data else {
                setDefaultOwnerInfo()
                return
            }
            
            let dto = try JSONDecoder().decode(ProfileDTO.self, from: data)
            let fullName = dto.full_name ?? "Owner"
            let rating = dto.rating ?? 4.7
            let distanceKm = dto.distance_km ?? 2.3
            let avatarUrlString = dto.avatar_url
            
            DispatchQueue.main.async { [weak self] in
                self?.ownerName.text = fullName
                self?.ownerRating.text = String(format: "%.1f", rating)
                self?.ownerDist.text = String(format: "%.1f km", distanceKm)
                self?.productRatingLabel?.text = String(format: "★ %.1f", rating)
                self?.productDistance?.text = String(format: "%.1f km", distanceKm)
            }
            
            if let avatarUrlString = avatarUrlString,
               let avatarUrl = URL(string: avatarUrlString) {
                UIImageView.rw_loadImage(from: avatarUrl) { [weak self] img in
                    DispatchQueue.main.async {
                        self?.ownerImage.image = img
                        self?.ownerImage.contentMode = .scaleAspectFill
                        self?.ownerImage.clipsToBounds = true
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.ownerImage.image = UIImage(systemName: "person.circle")
                    self?.ownerImage.tintColor = .secondaryLabel
                    self?.ownerImage.contentMode = .scaleAspectFit
                }
            }
        } catch {
            setDefaultOwnerInfo()
        }
    }
    
    private func setDefaultOwnerInfo() {
        DispatchQueue.main.async { [weak self] in
            self?.ownerName.text = "Owner"
            self?.ownerRating.text = "4.7"
            self?.ownerDist.text = "2.3 km"
            self?.ownerImage.image = UIImage(systemName: "person.circle")
            self?.ownerImage.tintColor = .secondaryLabel
            self?.ownerImage.contentMode = .scaleAspectFit
        }
    }
    
    private func updateRentalButtons() {
        let selectedColor = UIColor(hex: "5DA9B6").cgColor
        let normalColor = UIColor.systemGray4.cgColor
        
        hourButton.layer.cornerRadius = 20
        hourButton.layer.borderWidth = 1
        hourButton.layer.masksToBounds = true
        dayButton.layer.cornerRadius = 20
        dayButton.layer.borderWidth = 1
        dayButton.layer.masksToBounds = true
        
        // Default state: no selection (both normal)
        hourButton.layer.borderColor = normalColor
        dayButton.layer.borderColor = normalColor
        hourButton.backgroundColor = .white
        dayButton.backgroundColor = .white
        
        switch rentalUnit {
        case .none:
            break // keep both normal
        case .hour:
            hourButton.layer.borderColor = selectedColor
        case .day:
            dayButton.layer.borderColor = selectedColor
        }
    }
    
    private func selectUnit(_ unit: RentalUnit) {
        rentalUnit = unit
        updateRentalButtons()
        switch unit {
        case .hour:
            dateLabel.datePickerMode = .date
            pickuptimeLabel.datePickerMode = .time
            returntimeLabel.datePickerMode = .time
            dateTitleLabel.text = "Date"
            returnTimeTitleLabel.text = "Return Time"
            pickuptimeLabel.accessibilityLabel = "Pickup Time"
            dateLabel.accessibilityLabel = "Date"
            returntimeLabel.accessibilityLabel = "Return Time"
        case .day:
            dateLabel.datePickerMode = .date
            pickuptimeLabel.datePickerMode = .time
            returntimeLabel.datePickerMode = .date
            dateTitleLabel.text = "Pickup Date"
            returnTimeTitleLabel.text = "Return Date"
            pickuptimeLabel.accessibilityLabel = "Pickup Time"
            dateLabel.accessibilityLabel = "Pickup Date"
            returntimeLabel.accessibilityLabel = "Return Date"
            let startOfPickup = Calendar.current.startOfDay(for: dateLabel.date)
            if returntimeLabel.date < startOfPickup {
                returntimeLabel.date = startOfPickup
            }
        case .none:
            break
        }
        updatePickerTextColors()
        boookingcontainer?.isHidden = false
        Task { await populateUI() }
        recalculatePricing()
    }
    
    // MARK: - IBActions
    
    @IBAction func didTapHour(_ sender: UIButton) {
        if rentalUnit == .hour {
            rentalUnit = .none // deselect
            boookingcontainer?.isHidden = true
            label1sum?.text = ""
            label2sum?.text = ""
            label3sum?.text = ""
        } else {
            selectUnit(.hour)
        }
        updateRentalButtons()
    }
    
    @IBAction func didTapDay(_ sender: UIButton) {
        if rentalUnit == .day {
            rentalUnit = .none // deselect
            boookingcontainer?.isHidden = true
            label1sum?.text = ""
            label2sum?.text = ""
            label3sum?.text = ""
        } else {
            selectUnit(.day)
        }
        updateRentalButtons()
    }
    
    @IBAction func didTapSendRequest(_ sender: UIButton) {
        Task { await sendRequest() }
    }
    
    @IBAction func requestRentalclicked(_ sender: UIButton) {
        // Treat this as the "Request" action and use the existing flow.
        Task { await sendRequest() }
    }
    
    @objc private func datePickerChanged(_ sender: UIDatePicker) {
        if sender === dateLabel { hasSelectedDate = true }
        if sender === pickuptimeLabel { hasSelectedPickupTime = true }
        if sender === returntimeLabel { hasSelectedReturnTime = true }
        updatePickerTextColors()
        recalculatePricing()
        if rentalUnit != .none {
            boookingcontainer?.isHidden = false
        }
        applyItemToUI()
    }
    
    // MARK: - Pricing Logic
    
    private func recalculatePricing() {
        if rentalUnit == .none { return }
        guard let item = item else { return }
        let pricePerDay = item.price_per_day
        let pricePerHour = (pricePerDay / 8).rounded(toPlaces: 2)
        let calendar = Calendar.current
        let baseDate = dateLabel.date
        var startComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let pickupTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: pickuptimeLabel.date)
        startComponents.hour = pickupTimeComponents.hour
        startComponents.minute = pickupTimeComponents.minute
        startComponents.second = pickupTimeComponents.second
        guard let startDateTime = calendar.date(from: startComponents) else { return }
        let endDateTime: Date
        switch rentalUnit {
        case .hour:
            var endComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            let returnTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: returntimeLabel.date)
            endComponents.hour = returnTimeComponents.hour
            endComponents.minute = returnTimeComponents.minute
            endComponents.second = returnTimeComponents.second
            endDateTime = calendar.date(from: endComponents) ?? returntimeLabel.date
        case .day:
            let returnDate = returntimeLabel.date
            var endComponents = calendar.dateComponents([.year, .month, .day], from: returnDate)
            let pickupTimeComps = calendar.dateComponents([.hour, .minute, .second], from: pickuptimeLabel.date)
            endComponents.hour = pickupTimeComps.hour
            endComponents.minute = pickupTimeComps.minute
            endComponents.second = pickupTimeComps.second
            endDateTime = calendar.date(from: endComponents) ?? returnDate
        case .none:
            return
        }
        var actualEndDateTime = endDateTime
        if actualEndDateTime < startDateTime {
            actualEndDateTime = calendar.date(byAdding: .day, value: 1, to: actualEndDateTime) ?? actualEndDateTime
        }
        let duration = actualEndDateTime.timeIntervalSince(startDateTime)
        var rentalFee: Double = 0
        var quantityDescription1 = ""
        var quantityDescription2 = ""
        var quantityDescription3 = ""
        switch rentalUnit {
        case .hour:
            let hoursRaw = max(0, duration / 3600)
            let quantityHours = max(1, Int(ceil(hoursRaw)))
            rentalFee = Double(quantityHours) * pricePerHour
            quantityDescription1 = dateFormatter.string(from: baseDate)
            quantityDescription2 = "\(timeFormatter.string(from: startDateTime)) - \(timeFormatter.string(from: actualEndDateTime))"
            if hoursRaw > 0 {
                let h = Int(hoursRaw)
                let m = Int((hoursRaw - Double(h)) * 60)
                if h > 0 && m > 0 { quantityDescription3 = "\(h)h \(m)m" }
                else if h > 0 { quantityDescription3 = "\(h)h" }
                else { quantityDescription3 = "\(m)m" }
            } else {
                quantityDescription3 = "0m"
            }
        case .day:
            let daysRaw = max(0, duration / 86400)
            let quantityDays = max(1, Int(ceil(daysRaw)))
            rentalFee = Double(quantityDays) * pricePerDay
            let startStr = dateFormatter.string(from: baseDate)
            let endStr = dateFormatter.string(from: actualEndDateTime)
            quantityDescription1 = "\(startStr) - \(endStr)"
            quantityDescription2 = timeFormatter.string(from: pickuptimeLabel.date)
            quantityDescription3 = "\(quantityDays) day\(quantityDays == 1 ? "" : "s")"
        case .none:
            return
        }
        let serviceFee = rentalFee * serviceFeeRate
        let total = rentalFee + serviceFee + securityDeposit
        rentalfee.text = currencyFormatter.string(from: NSNumber(value: rentalFee))
        fee.text = currencyFormatter.string(from: NSNumber(value: serviceFee))
        security.text = currencyFormatter.string(from: NSNumber(value: securityDeposit))
        totalamount.text = currencyFormatter.string(from: NSNumber(value: total))
        priceLabel.text = currencyFormatter.string(from: NSNumber(value: total))
        label1sum?.text = quantityDescription1
        label2sum?.text = quantityDescription2
        label3sum?.text = quantityDescription3
    }
    
    // MARK: - Networking: Send Request
    private func sendRequest() async {
        guard let item = item else {
            presentMissingItemAlert()
            return
        }
        guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
            presentAlert(title: "Error", message: "You must be logged in to send a request.")
            return
        }
        
        // Prepare booking values according to your public.requests schema
        let calendar = Calendar.current
        let pickupDate = dateLabel.date
        let pickupTime = pickuptimeLabel.date
        let returnPicker = returntimeLabel.date
        
        let startOfPickup = calendar.startOfDay(for: pickupDate)
        var endDate: Date
        switch rentalUnit {
        case .day:
            endDate = calendar.startOfDay(for: returnPicker)
            if endDate < startOfPickup {
                endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }
        case .hour:
            // If return time earlier than pickup time -> assume next day
            var endComponents = calendar.dateComponents([.year, .month, .day], from: pickupDate)
            let returnTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: returnPicker)
            endComponents.hour = returnTimeComponents.hour
            endComponents.minute = returnTimeComponents.minute
            endComponents.second = returnTimeComponents.second
            let endDateTime = calendar.date(from: endComponents) ?? returnPicker
            endDate = endDateTime < pickupTime ? calendar.date(byAdding: .day, value: 1, to: pickupDate) ?? pickupDate : pickupDate
        case .none:
            // If no rental unit selected, do not proceed
            presentAlert(title: "Error", message: "Please select a rental duration before sending a request.")
            return
        }
        
        // Format for SQL
        let sqlDateFormatter = DateFormatter()
        sqlDateFormatter.calendar = Calendar(identifier: .gregorian)
        sqlDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        sqlDateFormatter.dateFormat = "yyyy-MM-dd"
        
        let sqlTimeFormatter = DateFormatter()
        sqlTimeFormatter.calendar = Calendar(identifier: .gregorian)
        sqlTimeFormatter.timeZone = TimeZone.current
        sqlTimeFormatter.dateFormat = "HH:mm:ssXXXXX"
        
        struct NewRequestRow: Encodable {
            let item_id: String
            let owner_id: String
            let borrower_id: String
            let start_date: String
            let end_date: String
            let pickup_time: String?
            let status: String
            let message: String?
        }
        
        let row = NewRequestRow(
            item_id: item.id,
            owner_id: item.owner_id,
            borrower_id: currentUserId,
            start_date: sqlDateFormatter.string(from: startOfPickup),
            end_date: sqlDateFormatter.string(from: endDate),
            pickup_time: sqlTimeFormatter.string(from: pickupTime),
            status: "pending",
            message: nil
        )
        
        do {
            _ = try await SupabaseManager.shared.client
                .from("requests")
                .insert(row)
                .execute()
            
            // Prepare values for RequestSentPage
            var startComponents = calendar.dateComponents([.year, .month, .day], from: pickupDate)
            let pickupTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: pickupTime)
            startComponents.hour = pickupTimeComponents.hour
            startComponents.minute = pickupTimeComponents.minute
            startComponents.second = pickupTimeComponents.second
            let bookingStartDate = calendar.date(from: startComponents) ?? pickupDate
            
            let bookingEndDate: Date
            switch rentalUnit {
            case .day:
                var endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
                endComponents.hour = pickupTimeComponents.hour
                endComponents.minute = pickupTimeComponents.minute
                endComponents.second = pickupTimeComponents.second
                bookingEndDate = calendar.date(from: endComponents) ?? endDate
            case .hour:
                var endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
                let returnTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: returnPicker)
                endComponents.hour = returnTimeComponents.hour
                endComponents.minute = returnTimeComponents.minute
                endComponents.second = returnTimeComponents.second
                bookingEndDate = calendar.date(from: endComponents) ?? endDate
            case .none:
                bookingEndDate = endDate
            }
            
            NotificationCenter.default.post(name: Notification.Name("rentalRequestCreated"), object: nil, userInfo: ["item_id": item.id])
            
            let sentVC = RequestSentPageViewController(nibName: "RequestSentPageViewController", bundle: .main)
            sentVC.configure(with: item)
            sentVC.bookingStartDate = bookingStartDate
            sentVC.bookingEndDate = bookingEndDate
            sentVC.pickupTime = pickupTime
            navigationController?.pushViewController(sentVC, animated: true)
        } catch {
            presentAlert(title: "Request Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Helper
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func presentMissingItemAlert() {
        let alert = UIAlertController(title: "Unable to Load Item", message: "We couldn't find the item you're trying to request. Please go back and try again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            if let nav = self?.navigationController {
                nav.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true, completion: nil)
            }
        }))
        present(alert, animated: true)
    }
    
    private func applyItemToUI() {
        guard isViewLoaded, let currentItem = self.item else { return }
        productTitleLabel?.text = currentItem.title
        let pricePerHour = (currentItem.price_per_day / 8).rounded(toPlaces: 2)
        switch rentalUnit {
        case .day:
            let amount = NSNumber(value: currentItem.price_per_day)
            productRateLabel?.text = (currencyFormatter.string(from: amount) ?? "₹\(currentItem.price_per_day)") + " / day"
            secRate?.text = productRateLabel?.text
        case .hour:
            let amount = NSNumber(value: pricePerHour)
            productRateLabel?.text = (currencyFormatter.string(from: amount) ?? "₹\(pricePerHour)") + " / hour"
            secRate?.text = productRateLabel?.text
        case .none:
            productRateLabel?.text = nil
            secRate?.text = nil
        }
        if let firstImagePath = currentItem.images.first, let url = StorageURLBuilder.publicFileURL(for: firstImagePath) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    self?.productThumbImageView.image = img
                    self?.productThumbImageView.contentMode = .scaleAspectFill
                    self?.productThumbImageView.clipsToBounds = true
                }
            }
        } else {
            productThumbImageView?.image = UIImage(systemName: "photo")
            productThumbImageView?.tintColor = .secondaryLabel
            productThumbImageView?.contentMode = .scaleAspectFit
        }
        if rentalUnit != .none { recalculatePricing() }
    }
    
    private func loadItemIfNeeded() {
        guard item == nil, let id = itemId else { return }
        Task { await fetchItemIfNeeded() }
    }
}

fileprivate extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return Darwin.round(self * divisor) / divisor
    }
}


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

extension UIImageView {
    static func rw_loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                completion(img)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
}

