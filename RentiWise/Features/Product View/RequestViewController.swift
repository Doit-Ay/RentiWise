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
    // Removed priceLabel
    @IBOutlet weak var rentalfee: UILabel!     // Static title: "Rental fee"
    @IBOutlet weak var totalamount: UILabel!
    @IBOutlet weak var secRate: UILabel!       // Shows security deposit amount
    @IBOutlet weak var fee: UILabel!           // Shows computed rental fee amount
    @IBOutlet weak var security: UILabel!      // Static title: "Security deposit"
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
//        itemcardview?.applyGlassEffectSimple()
//        rentalTypeCard?.applyGlassEffectSimple()
//        selectdateandtimeCard?.applyGlassEffectSimple()
//        bookingsummaryCard?.applyGlassEffectSimple()
//        ownerCard?.applyGlassEffectSimple()
//        priceBreakdownCard?.applyGlassEffectSimple()
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
            // Fetch all columns so Item.average_rating/review_count are populated if available
            let response = try await client
                .from("items")
                .select() // all columns (matches ItemsService)
                .eq("id", value: itemId)
                .single()
                .execute()
            
            if let data = response.data as? Data {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
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
        await fetchAndDisplayOwnerUnified(for: item.owner_id)
        securityDeposit = item.deposit_amount
        recalculatePricing()
        
        // Update distance using DistanceService (async)
        productDistance?.text = "..."
        ownerDist?.text = "..."
        Task { [weak self] in
            guard let self = self, let it = self.item else { return }
            let text = await DistanceService.shared.distanceText(for: it)
            await MainActor.run {
                self.productDistance?.text = text
                self.ownerDist?.text = text
            }
        }
    }
    
    // Unify with ProductViewController behavior: try user_profiles first, then profiles; handle http vs storage; fallback to initials.
    private func urlForAvatarPath(_ path: String) -> URL? {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path)
        } else {
            return StorageURLBuilder.publicFileURL(for: path)
        }
    }
    
    private func makeInitials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let first = parts.first?.first.map { String($0).uppercased() } ?? ""
        let last = parts.dropFirst().last?.first.map { String($0).uppercased() } ?? ""
        let combined = first + last
        return combined.isEmpty ? "?" : combined
    }
    
    private func drawInitialsImage(initials: String, size: CGSize) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(ovalIn: rect).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.4, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let textSize = (initials as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2.0,
                y: (size.height - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            (initials as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func renderOwnerInitials(fullName: String) {
        let initials = makeInitials(from: fullName)
        let size = ownerImage?.bounds.size == .zero || ownerImage?.bounds.size == nil ? CGSize(width: 60, height: 60) : ownerImage!.bounds.size
        ownerImage?.image = drawInitialsImage(initials: initials, size: size)
        ownerImage?.contentMode = .scaleAspectFill
        ownerImage?.clipsToBounds = true
        ownerImage?.backgroundColor = .clear
    }
    
    private func renderOwner(fullName: String?, avatarURLString: String?) {
        let name = (fullName?.isEmpty == false) ? fullName! : "Owner"
        ownerName?.text = name
        // If rating not set yet, keep a neutral placeholder; product rating will be set from item stats
        if ownerRating?.text?.isEmpty ?? true {
            ownerRating?.text = "★ 4.5"
        }
        // Distance will be updated via DistanceService; keep placeholder if empty
        if ownerDist?.text?.isEmpty ?? true {
            ownerDist?.text = "..."
        }
        
        if let avatar = avatarURLString, !avatar.isEmpty, let url = urlForAvatarPath(avatar) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    if let img = img {
                        self?.ownerImage?.image = img
                        self?.ownerImage?.contentMode = .scaleAspectFill
                        self?.ownerImage?.clipsToBounds = true
                    } else {
                        self?.renderOwnerInitials(fullName: name)
                    }
                }
            }
        } else {
            renderOwnerInitials(fullName: name)
        }
    }
    
    private func fetchAndDisplayOwnerUnified(for ownerId: String) async {
        struct ProfilesDTO: Decodable {
            let full_name: String?
            let avatar_url: String?
            let rating: Double?
            let distance_km: Double?
        }
        
        do {
            let client = SupabaseManager.shared.client
            // Read from public view so it works for logged out users
            if let usersData = try? await client
                .from("user_profiles")
                .select("id,full_name,profile_photo_url")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                
                struct UsersDTO: Decodable {
                    let id: String
                    let full_name: String?
                    let profile_photo_url: String?
                }
                let dto = try JSONDecoder().decode(UsersDTO.self, from: usersData)
                renderOwner(fullName: dto.full_name, avatarURLString: dto.profile_photo_url)
                return
            }
            
            // Optional fallback if you still maintain a separate profiles table
            if let profilesData = try? await client
                .from("profiles")
                .select("full_name,avatar_url,rating,distance_km")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                
                let dto = try JSONDecoder().decode(ProfilesDTO.self, from: profilesData)
                renderOwner(fullName: dto.full_name, avatarURLString: dto.avatar_url)
                
                if let r = dto.rating {
                    ownerRating?.text = String(format: "★ %.1f", r)
                    productRatingLabel?.text = String(format: "★ %.1f", r)
                }
                if let d = dto.distance_km {
                    let distText = String(format: "%.1f km", d)
                    ownerDist?.text = distText
                    productDistance?.text = distText
                }
                return
            }
            
            renderOwner(fullName: "Owner", avatarURLString: nil)
        } catch {
            renderOwner(fullName: "Owner", avatarURLString: nil)
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
        
        hourButton.layer.borderColor = normalColor
        dayButton.layer.borderColor = normalColor
        hourButton.backgroundColor = .white
        dayButton.backgroundColor = .white
        
        switch rentalUnit {
        case .none:
            break
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
            rentalUnit = .none
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
            rentalUnit = .none
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
        var rentalFeeAmount: Double = 0
        var quantityDescription1 = ""
        var quantityDescription2 = ""
        var quantityDescription3 = ""
        
        switch rentalUnit {
        case .hour:
            let hoursRaw = max(0, duration / 3600)
            let quantityHours = max(1, Int(ceil(hoursRaw)))
            rentalFeeAmount = Double(quantityHours) * pricePerHour
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
            rentalFeeAmount = Double(quantityDays) * pricePerDay
            let startStr = dateFormatter.string(from: baseDate)
            let endStr = dateFormatter.string(from: actualEndDateTime)
            quantityDescription1 = "\(startStr) - \(endStr)"
            quantityDescription2 = timeFormatter.string(from: pickuptimeLabel.date)
            quantityDescription3 = "\(quantityDays) day\(quantityDays == 1 ? "" : "s")"
        case .none:
            return
        }
        
        // If you do not want to include service fee in totalamount, exclude it here.
        // Keep computing it if you’ll use it elsewhere visually.
        let serviceFee = rentalFeeAmount * serviceFeeRate
        let total = rentalFeeAmount /* + serviceFee */ + securityDeposit
        
        // Assign amounts to the correct labels per your requirement:
        // - fee: shows the computed rental fee amount
        // - secRate: shows the security deposit amount
        // - rentalfee and security are static titles; do not change them here
        fee.text = currencyFormatter.string(from: NSNumber(value: rentalFeeAmount))
        secRate.text = currencyFormatter.string(from: NSNumber(value: securityDeposit))
        
        totalamount.text = currencyFormatter.string(from: NSNumber(value: total))
        
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
            var endComponents = calendar.dateComponents([.year, .month, .day], from: pickupDate)
            let returnTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: returnPicker)
            endComponents.hour = returnTimeComponents.hour
            endComponents.minute = returnTimeComponents.minute
            endComponents.second = returnTimeComponents.second
            let endDateTime = calendar.date(from: endComponents) ?? returnPicker
            endDate = endDateTime < pickupTime ? calendar.date(byAdding: .day, value: 1, to: pickupDate) ?? pickupDate : pickupDate
        case .none:
            presentAlert(title: "Error", message: "Please select a rental duration before sending a request.")
            return
        }
        
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
        
        guard let itemObj = self.item else { return }
        let row = NewRequestRow(
            item_id: itemObj.id,
            owner_id: itemObj.owner_id,
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
            
            NotificationCenter.default.post(name: Notification.Name("rentalRequestCreated"), object: nil, userInfo: ["item_id": itemObj.id])
            
            let sentVC = RequestSentPageViewController(nibName: "RequestSentPageViewController", bundle: .main)
            sentVC.configure(with: itemObj)
            sentVC.bookingStartDate = bookingStartDate
            sentVC.bookingEndDate = bookingEndDate
            sentVC.pickupTime = pickupTime
            sentVC.isPerHour = (rentalUnit == .hour)
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
        case .hour:
            let amount = NSNumber(value: pricePerHour)
            productRateLabel?.text = (currencyFormatter.string(from: amount) ?? "₹\(pricePerHour)") + " / hour"
        case .none:
            productRateLabel?.text = nil
        }
        
        // Rating from item stats if available; else show a friendly placeholder
        if let avg = currentItem.average_rating, let count = currentItem.review_count, count > 0 {
            productRatingLabel?.attributedText = makeYellowStarRatingText(valueText: String(format: "%.1f", avg), reviewsText: nil)
        } else {
            productRatingLabel?.attributedText = nil
            productRatingLabel?.text = "No reviews"
            productRatingLabel?.textColor = .secondaryLabel
            productRatingLabel?.font = .systemFont(ofSize: 13, weight: .regular)
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
        
        // Distance will be updated asynchronously in populateUI()
        if productDistance?.text?.isEmpty ?? true {
            productDistance?.text = "..."
        }
        
        if rentalUnit != .none { recalculatePricing() }
    }
    
    private func makeYellowStarRatingText(valueText: String, reviewsText: String? = nil) -> NSAttributedString {
        let star = "★"
        let space = " "
        let rest = [valueText, reviewsText].compactMap { $0 }.joined(separator: " ")
        let full = star + space + rest

        let attr = NSMutableAttributedString(string: full, attributes: [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 14, weight: .regular)
        ])

        if let starRange = full.range(of: star) {
            let ns = NSRange(starRange, in: full)
            attr.addAttribute(.foregroundColor, value: UIColor.systemYellow, range: ns)
        }
        return attr
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
            let image: UIImage? = if let data = data { UIImage(data: data) } else { nil }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
}

