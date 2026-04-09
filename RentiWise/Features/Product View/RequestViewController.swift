//
//  RequestViewController.swift
//  ProductDetails
//
//  Created by user@48 on 14/11/25.
//

import UIKit
import Supabase
import CoreLocation

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
    @IBOutlet weak var upiNoteLabel: UILabel!  // shows UPI note under total
    
    // MARK: - Private Properties
    
    private var item: Item?
    private var itemId: String?
    private var hasPresentedBlockedOwnerAlert = false
    private var isSubmittingRequest = false

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
    
    private var securityDeposit: Double = 0 // No deposit in TestFlight build
    
    // Removed serviceFeeRate
    // private let serviceFeeRate: Double = 0.10
    
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
        
        // Configure UPI note label
        if let note = upiNoteLabel {
            note.text = "Payment will be arranged directly with the lender via UPI after your request is accepted."
            note.textColor = .secondaryLabel
            note.font = .systemFont(ofSize: 13, weight: .regular)
            note.numberOfLines = 0
        }
        
        applyGlassToCards()
        dateLabel.minimumDate = Date()
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
            debugLog("[RequestVC] Warning: One or more IBOutlets are not connected in Interface Builder.")
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
            
            let data = response.data
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let fetched = try decoder.decode(Item.self, from: data)
            self.item = fetched
            await populateUI()
        } catch {
            await MainActor.run { [weak self] in
                self?.presentMissingItemAlert()
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func populateUI() async {
        guard let item = item else { return }
        if CommunitySafetyService.shared.isBlocked(item.owner_id) {
            presentBlockedOwnerAlertIfNeeded()
            return
        }
        applyItemToUI()
        await fetchAndDisplayOwnerUnified(for: item.owner_id)
        // Removed securityDeposit assignment to skip deposit
        // securityDeposit = item.deposit_amount
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
        let size = ownerImage?.bounds.size == .zero
            ? CGSize(width: 60, height: 60)
            : (ownerImage?.bounds.size ?? CGSize(width: 60, height: 60))
        ownerImage?.image = drawInitialsImage(initials: initials, size: size)
        ownerImage?.contentMode = .scaleAspectFill
        ownerImage?.clipsToBounds = true
        ownerImage?.backgroundColor = .clear
    }
    
    private func renderOwner(fullName: String?, avatarURLString: String?) {
        let name = (fullName?.isEmpty == false) ? fullName! : "Owner"
        ownerName?.text = name
        // Rating is set from item's average_rating (see applyItemToUI); do not overwrite with hardcoded value
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
                .data {
                
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
                .data {
                
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
        hasSelectedReturnTime = false
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
            returntimeLabel.minimumDate = startOfPickup
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
        if sender === dateLabel {
            hasSelectedDate = true
            // If rental unit is day, make sure return date can't be before pickup date
            if rentalUnit == .day {
                let startOfPickup = Calendar.current.startOfDay(for: dateLabel.date)
                returntimeLabel.minimumDate = startOfPickup
                if returntimeLabel.date < startOfPickup {
                    returntimeLabel.date = startOfPickup
                }
            }
        }
        if sender === pickuptimeLabel { hasSelectedPickupTime = true }
        if sender === returntimeLabel { hasSelectedReturnTime = true }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Enforce time restrictions dynamically
        if calendar.isDate(dateLabel.date, inSameDayAs: now) {
            pickuptimeLabel.minimumDate = now
            if pickuptimeLabel.date < now {
                pickuptimeLabel.date = now
            }
        } else {
            pickuptimeLabel.minimumDate = nil
        }
        
        if rentalUnit == .hour {
            returntimeLabel.minimumDate = pickuptimeLabel.date
            if returntimeLabel.date < pickuptimeLabel.date {
                returntimeLabel.date = pickuptimeLabel.date
            }
        }
        
        updatePickerTextColors()
        recalculatePricing()
        if rentalUnit != .none {
            boookingcontainer?.isHidden = false
        }
        applyItemToUI()
        
        // Auto-close compact date picker popover after selection only for Dates (Calendars)
        // We do not close on Times because the user needs to scroll the time wheel continuously
        if sender.datePickerMode == .date {
            if let presented = self.presentedViewController, !presented.isBeingDismissed {
                presented.dismiss(animated: true, completion: nil)
            }
            sender.resignFirstResponder()
        }
    }
    
    // MARK: - Pricing Logic
    
    private func recalculatePricing() {
        if rentalUnit == .none { return }
        guard let item = item else { return }
        let booking = BookingPresentationFormatter.presentation(
            startDate: dateLabel.date,
            pickupTime: pickuptimeLabel.date,
            returnSelection: returntimeLabel.date,
            rentalUnit: rentalUnit == .hour ? .hour : .day,
            pricePerDay: item.price_per_day
        )

        let rentalFeeAmount = booking.rentalFee
        let quantityDescription1 = booking.dateText
        let quantityDescription2 = booking.timeText
        let quantityDescription3 = booking.durationText
        
        // Removed service fee and deposit from total calculation
        // let serviceFee = rentalFeeAmount * serviceFeeRate
        let total = rentalFeeAmount
        
        // Assign amounts to the correct labels per your requirement:
        // - fee: shows the computed rental fee amount
        // - secRate: repurposed in XIB as 'Payment Note' value ("Direct via UPI"), so we keep it visible
        // - rentalfee and security are static titles; security is repurposed in XIB as 'Payment Note'
        
        fee.text = currencyFormatter.string(from: NSNumber(value: rentalFeeAmount))
        secRate?.text = "Direct via UPI"
        security?.isHidden = false
        secRate?.isHidden = false
        
        totalamount.text = currencyFormatter.string(from: NSNumber(value: total))
        
        label1sum?.text = quantityDescription1
        label2sum?.text = quantityDescription2
        label3sum?.text = quantityDescription3
    }
    
    // MARK: - Networking: Send Request
    private func sendRequest() async {
        guard !isSubmittingRequest else { return }
        guard let item = item else {
            presentMissingItemAlert()
            return
        }
        if CommunitySafetyService.shared.isBlocked(item.owner_id) {
            presentBlockedOwnerAlertIfNeeded()
            return
        }
        guard let currentUserId = await SupabaseManager.shared.currentUserId() else {
            presentAlert(title: "Error", message: "You must be logged in to send a request.")
            return
        }
        guard item.owner_id.caseInsensitiveCompare(currentUserId) != .orderedSame else {
            presentAlert(title: "Own Listing", message: "You can't send a rental request for your own listing.")
            return
        }
        guard rentalUnit != .none else {
            presentAlert(title: "Missing Details", message: "Please choose whether you're renting by the hour or by the day.")
            return
        }
        if let selectionMessage = bookingSelectionValidationMessage() {
            presentAlert(title: "Missing Details", message: selectionMessage)
            return
        }

        // Validate dates are not in the past
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let selectedDate = Calendar.current.startOfDay(for: dateLabel.date)
        guard selectedDate >= startOfToday else {
            presentAlert(title: "Invalid Date", message: "The pickup date cannot be in the past.")
            return
        }

        // Validate return is after start for day rentals
        if rentalUnit == .day {
            let returnDate = Calendar.current.startOfDay(for: returntimeLabel.date)
            guard returnDate >= selectedDate else {
                presentAlert(title: "Invalid Date", message: "The return date must be on or after the pickup date.")
                return
            }
        }

        do {
            let profile = try await ProfileService().fetchCurrentUserProfile()
            if let blocker = borrowingBlockerMessage(for: profile, item: item) {
                presentBorrowingBlockedAlert(message: blocker)
                return
            }
        } catch {
            presentBorrowingBlockedAlert(message: "Complete your profile before sending a request.")
            return
        }

        do {
            if try await hasExistingActiveRequest(itemId: item.id, borrowerId: currentUserId) {
                presentAlert(title: "Request Already Sent", message: "You already have an active request for this item.")
                return
            }
        } catch {
            presentAlert(title: "Request Check Failed", message: "We couldn't confirm whether you already requested this item. Please try again.")
            return
        }

        isSubmittingRequest = true
        defer { isSubmittingRequest = false }
        
        let booking = BookingPresentationFormatter.presentation(
            startDate: dateLabel.date,
            pickupTime: pickuptimeLabel.date,
            returnSelection: returntimeLabel.date,
            rentalUnit: rentalUnit == .hour ? .hour : .day,
            pricePerDay: item.price_per_day
        )

        struct NewRequestRow: Encodable {
            let item_id: String
            let owner_id: String
            let borrower_id: String
            let start_date: String
            let end_date: String
            let pickup_time: String?
            let status: String
            let message: String?
            let borrower_lat: Double?
            let borrower_lng: Double?
            let borrower_location_captured_at: String?
            let rental_unit: String?
            let return_time: String?
        }
        
        guard let itemObj = self.item else { return }

        // Capture GPS silently — non-blocking, non-required
        let coordinates = await AppLocationManager.shared.currentCoordinates()
        let locationTimestamp: String? = coordinates != nil ? ISO8601DateFormatter().string(from: Date()) : nil

        let row = NewRequestRow(
            item_id: itemObj.id,
            owner_id: itemObj.owner_id,
            borrower_id: currentUserId,
            start_date: BookingPresentationFormatter.sqlDateString(for: booking.pickupDateTime),
            end_date: BookingPresentationFormatter.sqlDateString(for: booking.returnDateTime),
            pickup_time: BookingPresentationFormatter.sqlTimeString(for: booking.pickupDateTime),
            status: "pending",
            message: nil,
            borrower_lat: coordinates?.latitude,
            borrower_lng: coordinates?.longitude,
            borrower_location_captured_at: locationTimestamp,
            rental_unit: rentalUnit == .hour ? "hour" : "day",
            return_time: BookingPresentationFormatter.sqlTimeString(for: booking.returnDateTime)
        )
        
        do {
            struct RequestIdRow: Decodable { let id: String }

            let insertedRequest: RequestIdRow = try await SupabaseManager.shared.client
                .from("requests")
                .insert(row)
                .select("id")
                .single()
                .execute()
                .value

            RemoteNotificationService.sendNewRequest(
                requestId: insertedRequest.id,
                ownerId: itemObj.owner_id,
                itemTitle: itemObj.title
            )
            
            NotificationCenter.default.post(name: Notification.Name("rentalRequestCreated"), object: nil, userInfo: ["item_id": itemObj.id])

            // Track analytics event
            let rentalDays = max(1, Int(ceil(booking.returnDateTime.timeIntervalSince(booking.pickupDateTime) / 86400.0)))
            AnalyticsService.shared.trackRentalRequestSent(itemId: itemObj.id, days: rentalDays)
            
            let sentVC = RequestSentPageViewController(nibName: "RequestSentPageViewController", bundle: .main)
            sentVC.configure(with: itemObj)
            sentVC.bookingStartDate = booking.pickupDateTime
            sentVC.bookingEndDate = booking.returnDateTime
            sentVC.pickupTime = booking.pickupDateTime
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

    private func bookingSelectionValidationMessage() -> String? {
        guard hasSelectedDate else {
            return rentalUnit == .day ? "Please choose your pickup date." : "Please choose your rental date."
        }
        guard hasSelectedPickupTime else {
            return "Please choose a pickup time."
        }
        guard hasSelectedReturnTime else {
            return rentalUnit == .day ? "Please choose a return date." : "Please choose a return time."
        }
        
        // Enforce 1 hour minimum booking duration
        if let item = self.item {
            let booking = BookingPresentationFormatter.presentation(
                startDate: dateLabel.date,
                pickupTime: pickuptimeLabel.date,
                returnSelection: returntimeLabel.date,
                rentalUnit: rentalUnit == .hour ? .hour : .day,
                pricePerDay: item.price_per_day
            )
            if booking.durationSeconds < 3600 {
                return "The minimum rental duration is 1 hour."
            }
        }
        
        return nil
    }

    private func hasExistingActiveRequest(itemId: String, borrowerId: String) async throws -> Bool {
        struct ActiveRequestRow: Decodable {
            let id: String
        }

        let response = try await SupabaseManager.shared.client
            .from("requests")
            .select("id")
            .eq("item_id", value: itemId)
            .eq("borrower_id", value: borrowerId)
            .in("status", values: ["pending", "accepted", "approved"])
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([ActiveRequestRow].self, from: response.data)
        return !rows.isEmpty
    }

    private func borrowingBlockerMessage(for profile: UserProfile, item: Item) -> String? {
        if let freezeUntil = profile.borrowFreezeUntil, freezeUntil > Date() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "Your borrowing is temporarily frozen until \(formatter.string(from: freezeUntil))."
        }

        let declaredValue = item.declared_value ?? 0

        if profile.totalRentalsAsBorrower == 0 && declaredValue > 1500 {
            return "To keep borrowing safe for both lenders and new members, higher-value items unlock after your first completed rental. Right now, new accounts can request items up to ₹1,500. Once you finish one rental, this limit is removed."
        }

        if profile.totalRentalsAsBorrower > 0,
           profile.averageRating > 0,
           profile.averageRating < 3.5,
           declaredValue > 2000 {
            return "Your rating must be 3.5 or higher to borrow items above 2,000 INR."
        }

        return nil
    }

    private func presentBorrowingBlockedAlert(message: String) {
        let alert = UIAlertController(title: "Complete One Rental First", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Profile", style: .default, handler: { [weak self] _ in
            self?.routeToProfileTab()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func routeToProfileTab() {
        let profileTabIndex = 1

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let tab = window.rootViewController as? UITabBarController,
           profileTabIndex < (tab.viewControllers?.count ?? 0) {
            tab.selectedIndex = profileTabIndex
            navigationController?.popToRootViewController(animated: true)
            return
        }

        let profileVC = ProfileViewController()
        profileVC.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    private func applyItemToUI() {
        guard isViewLoaded, let currentItem = self.item else { return }
        if CommunitySafetyService.shared.isBlocked(currentItem.owner_id) {
            presentBlockedOwnerAlertIfNeeded()
            return
        }
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
        
        // Hide security deposit labels since no deposit is used (TestFlight)
        security?.isHidden = true
        secRate?.isHidden = true
        
        if rentalUnit != .none { recalculatePricing() }
    }

    private func presentBlockedOwnerAlertIfNeeded() {
        guard !hasPresentedBlockedOwnerAlert else { return }
        hasPresentedBlockedOwnerAlert = true

        let alert = UIAlertController(
            title: "User Blocked",
            message: "You blocked this lender. Unblock them in Privacy & Security to request this item again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            if let nav = self?.navigationController {
                nav.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        }))
        present(alert, animated: true)
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
