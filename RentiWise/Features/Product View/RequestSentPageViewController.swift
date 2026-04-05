//
//  RequestSentPageViewController.swift
//  ProductDetails
//
//  Created by user@48 on 18/11/25.
//

import UIKit
import Supabase

class RequestSentPageViewController: UIViewController {
    
    var item: Item?
    
    // State for pricing mode and booking
    private enum RentalUnit { case perHour, perDay }
    private var rentalUnit: RentalUnit = .perDay { didSet { updatePriceLabels() } }

    // Inputs for booking summary (set these from previous screen)
    var bookingStartDate: Date?
    var bookingEndDate: Date?
    var pickupTime: Date?
    /// Set to true when the user selected the per-hour rental mode in RequestViewController.
    var isPerHour: Bool = false
    
    @IBOutlet weak var CircleView: UIView!
    @IBOutlet weak var checkmark: UIImageView!
    @IBOutlet weak var rentalItemCardView: UIView!
    @IBOutlet weak var productThumbImageView: UIImageView!
    @IBOutlet weak var productTitleLabel: UILabel!
    @IBOutlet weak var productCategoryLabel: UILabel!
    @IBOutlet weak var rentalIteminsideView: UIView!
    @IBOutlet weak var rentalLabel: UILabel!
    @IBOutlet weak var bookingPeriodCardView: UIView!
    @IBOutlet weak var bookingPeriodTitleLabel: UILabel!
    @IBOutlet weak var bookingDateRangeLabel: UILabel!
    @IBOutlet weak var bookingDurationLabel: UILabel!
    @IBOutlet weak var bookingPickupTimeLabel: UILabel!
    @IBOutlet weak var bookingdateLabel: UILabel!
    @IBOutlet weak var pickuptimeLabel: UILabel!
    @IBOutlet weak var ownerCardView: UIView!
    @IBOutlet weak var ownerAvatarView: UIView!
    @IBOutlet weak var ownerNameLabel: UILabel!
    @IBOutlet weak var ownerstarRating: UILabel!
    @IBOutlet weak var ownerDistanceIconImageView: UIImageView!
    @IBOutlet weak var ownerDistanceLabel: UILabel!
    @IBOutlet weak var priceBreakdownCardView: UIView!
    @IBOutlet weak var pricebreakdownLabel: UILabel!
    @IBOutlet weak var rentalFeeLabel: UILabel!
    @IBOutlet weak var rentalFeeAmountLabel: UILabel!
    @IBOutlet weak var securityDepositLabel: UILabel!
    @IBOutlet weak var securityDepositAmountLabel: UILabel!
    @IBOutlet weak var totalTitleLabel: UILabel!
    @IBOutlet weak var totalAmountLabel: UILabel!
    
    @IBOutlet weak var perHourButton: UIButton?
    @IBOutlet weak var perDayButton: UIButton?
    
    @IBOutlet weak var upiInfoLabel: UILabel!  // Added informational label for UPI payment note
    
    private lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df
    }()
    
    private lazy var timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
    
    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
        static let dashboardListingID = "DashboardListing"
        static let homeStoryboardID = "Home" // if you have a storyboard ID for HomeViewController; not strictly required
    }
    
    func configure(with item: Item) {
        self.item = item
        if isViewLoaded { updateUI() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide back button — the request is already submitted, Done is the only exit
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = nil
        
        let cards: [UIView?] = [rentalItemCardView, rentalIteminsideView, bookingPeriodCardView, ownerCardView, priceBreakdownCardView]
        cards.forEach { card in
            guard let card = card else { return }
            card.rw_applyGlassEffect(
                cornerRadius: 16,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: .white,
                tintAlpha: 0.14,
                showsHighlight: true,
                highlightAlpha: 0.15
            )
            card.layer.shadowOpacity = 0.12
            card.layer.shadowRadius = 8
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
        }
        
        CircleView.layer.cornerRadius = CircleView.bounds.height / 2
        CircleView.layer.masksToBounds = true
        
        // Commented out because glass effect handles background
//        rentalItemCardView?.backgroundColor = .white
//        bookingPeriodCardView?.backgroundColor = .white
//        ownerCardView?.backgroundColor = .white
//        priceBreakdownCardView?.backgroundColor = .white
        
        // Initialize toggle visual state
        updateToggleUI()
        
        // Prepare animation initial state
        prepareSuccessAnimationInitialState()
        
        // Ensure thumbnail rounds like other cards
        productThumbImageView?.clipsToBounds = true
        productThumbImageView?.contentMode = .scaleAspectFill
        productThumbImageView?.layer.cornerRadius = 16
        
        updateUI()
        
        // Informational note about UPI payment after acceptance
        upiInfoLabel?.text = "You will be notified when the lender responds. If accepted, you can pay the lender directly via UPI."
        upiInfoLabel?.textColor = .secondaryLabel
        upiInfoLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        upiInfoLabel?.numberOfLines = 0
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-assert rounding in case the view resizes
        productThumbImageView?.layer.cornerRadius = 16
        productThumbImageView?.clipsToBounds = true
        
        // Ensure card views keep a 16pt corner radius after layout changes
        [rentalItemCardView, bookingPeriodCardView, ownerCardView, priceBreakdownCardView].forEach { v in
            guard let view = v else { return }
            view.layer.cornerRadius = 16
            view.layer.masksToBounds = false // keep shadows visible from glass effect
            // Also round/clip the material subviews (blur/tint) so the visible edge is rounded
            for sub in view.subviews where sub.tag == 987654 {
                sub.layer.cornerRadius = 16
                sub.layer.masksToBounds = true
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runSuccessAnimation()
    }
    
    @IBAction func didTapPerHour(_ sender: UIButton) {
        rentalUnit = .perHour
        updateToggleUI()
        // Recompute duration label to reflect new unit
        updateBookingLabels()
    }

    @IBAction func didTapPerDay(_ sender: UIButton) {
        rentalUnit = .perDay
        updateToggleUI()
        // Recompute duration label to reflect new unit
        updateBookingLabels()
    }
    
    private func updateUI() {
        guard let item = item else { return }

        // Sync rental unit from the flag passed by RequestViewController
        rentalUnit = isPerHour ? .perHour : .perDay

        // Title
        productTitleLabel?.text = item.title

        // Category (fallback to empty string if nil/empty)
        productCategoryLabel?.text = (item.category?.isEmpty == false) ? item.category : ""

        // Image
        if let firstImage = item.images.first,
           let url = StorageURLBuilder.publicFileURL(for: firstImage) {
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    self?.productThumbImageView?.image = img
                    // keep fill + rounded
                    self?.productThumbImageView?.contentMode = .scaleAspectFill
                    self?.productThumbImageView?.clipsToBounds = true
                }
            }
        } else {
            productThumbImageView?.image = nil
        }

        // Rental unit label
        rentalLabel?.text = (rentalUnit == .perHour) ? "Per hour" : "Per day"

        // Owner info: unified resolution like RequestViewController/ProductViewController
        Task { [weak self] in
            guard let self = self, let item = self.item else { return }
            await self.fetchAndDisplayOwnerUnified(for: item.owner_id)
        }

        // Update booking and pricing labels
        updateBookingLabels()
        updatePriceLabels()

        // Owner secondary labels default fallbacks if still empty
        if ownerstarRating?.text?.isEmpty ?? true {
            ownerstarRating?.text = "No rating"
        }
        if ownerDistanceLabel?.text?.isEmpty ?? true {
            ownerDistanceLabel?.text = "— km"
        }
    }
    
    private func updateBookingLabels() {
        guard let start = bookingStartDate,
              let end = bookingEndDate,
              let item = item else {
            bookingDateRangeLabel?.text = "—"
            bookingPickupTimeLabel?.text = "—"
            bookingDurationLabel?.text = "—"
            return
        }
        let booking = BookingPresentationFormatter.presentation(
            pickupDateTime: start,
            returnDateTime: end,
            rentalUnit: rentalUnit == .perHour ? .hour : .day,
            pricePerDay: item.price_per_day
        )

        bookingDateRangeLabel?.text = booking.dateText
        bookingPickupTimeLabel?.text = booking.timeText
        bookingDurationLabel?.text = booking.durationText
    }
    
    private func updatePriceLabels() {
        guard let item = item else { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let booking = BookingPresentationFormatter.presentation(
            pickupDateTime: bookingStartDate ?? Date(),
            returnDateTime: bookingEndDate ?? Date(),
            rentalUnit: rentalUnit == .perHour ? .hour : .day,
            pricePerDay: item.price_per_day
        )
        let rentalFee = booking.rentalFee

        // Totals align with RequestViewController: rental fee only for the TestFlight flow.
        let total = rentalFee

        let rentalFeeText = formatter.string(from: NSNumber(value: rentalFee)) ?? String(format: "%.2f", rentalFee)
        let totalText = formatter.string(from: NSNumber(value: total)) ?? String(format: "%.2f", total)
        rentalLabel?.text = (rentalUnit == .perHour) ? "Per hour" : "Per day"
        rentalFeeAmountLabel?.text = rentalFeeText
        totalAmountLabel?.text = totalText

        securityDepositLabel?.isHidden = false
        securityDepositAmountLabel?.text = "Direct via UPI"
        securityDepositAmountLabel?.isHidden = false
    }

    private func updateToggleUI() {
        // Basic visual feedback; wire to your design as needed
        perHourButton?.isSelected = (rentalUnit == .perHour)
        perDayButton?.isSelected = (rentalUnit == .perDay)
        perHourButton?.alpha = perHourButton?.isSelected == true ? 1.0 : 0.6
        perDayButton?.alpha = perDayButton?.isSelected == true ? 1.0 : 0.6
    }
    
    private func instantiateDashboardListing() -> UIViewController {
        let sb = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
        return sb.instantiateViewController(withIdentifier: Constants.dashboardListingID)
    }
    
    // Connect this IBAction to your "Request" / "Close" button if you want to simply leave this screen.
    @IBAction func requestRentalclicked(_ sender: UIButton) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    // IBAction for your Done button on the success screen. Connect in Interface Builder.
    @IBAction func didTapDone(_ sender: UIButton) {
        routeToHome()
    }
    
    @IBAction func gotodashboardbuttonTapped(_ sender: Any) {
        // Change behavior: act like "Done" and route to Home
        routeToHome()
    }
}

// MARK: - Success animation + routing to Home

private extension RequestSentPageViewController {
    func prepareSuccessAnimationInitialState() {
        // Start hidden and scaled down for a pop-in effect
        CircleView?.alpha = 0.0
        checkmark?.alpha = 0.0
        CircleView?.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        checkmark?.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    }
    
    func runSuccessAnimation() {
        // Light haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Pop-in circle
        UIView.animate(withDuration: 0.28, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.6, options: [.curveEaseInOut], animations: {
            self.CircleView?.alpha = 1.0
            self.CircleView?.transform = .identity
        }, completion: { _ in
            // Fade/scale in checkmark slightly after
            UIView.animate(withDuration: 0.24, delay: 0.04, options: [.curveEaseInOut], animations: {
                self.checkmark?.alpha = 1.0
                self.checkmark?.transform = .identity
            }, completion: { _ in
                // Gentle pulse
                UIView.animate(withDuration: 0.18, delay: 0.10, options: [.curveEaseInOut], animations: {
                    self.CircleView?.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                    self.checkmark?.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.18, delay: 0.0, options: [.curveEaseInOut], animations: {
                        self.CircleView?.transform = .identity
                        self.checkmark?.transform = .identity
                    }, completion: nil)
                })
            })
        })
    }
    
    func routeToHome() {
        // 1) Try to pop to an existing HomeViewController in the current nav stack
        if let nav = navigationController {
            if let homeVC = nav.viewControllers.first(where: { $0 is HomeViewController }) {
                nav.popToViewController(homeVC, animated: true)
                return
            }
            // 2) If root is HomeViewController, pop to root
            if let root = nav.viewControllers.first, root is HomeViewController {
                nav.popToRootViewController(animated: true)
                return
            }
        }
        
        // 3) Otherwise, reset root to AppStarting → assume Home is the initial controller in your app entry
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // If your app uses a Tab Bar with Home as the first tab, just ensure the tab bar is shown.
            // Here we assume AppStarting sets things up to show Home by default.
            let sb = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
            let root = sb.instantiateInitialViewController() ?? sb.instantiateViewController(withIdentifier: Constants.navigationBarID)
            window.rootViewController = root
            window.makeKeyAndVisible()
            return
        }
        
        // 4) Last resort: dismiss or pop to root if possible
        if let nav = navigationController {
            nav.popToRootViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - Owner resolution helpers (mirroring RequestViewController)

private extension RequestSentPageViewController {
    struct UsersDTO: Decodable {
        let id: String
        let full_name: String?
        let profile_photo_url: String?
    }
    struct ProfilesDTO: Decodable {
        let full_name: String?
        let avatar_url: String?
        let rating: Double?
        let distance_km: Double?
    }
    
    func fetchAndDisplayOwnerUnified(for ownerId: String) async {
        do {
            let client = SupabaseManager.shared.client
            if let usersData = try? await client
                .from("users")
                .select("id,full_name,profile_photo_url")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                
                let dto = try JSONDecoder().decode(UsersDTO.self, from: usersData)
                await MainActor.run { [weak self] in
                    self?.renderOwner(fullName: dto.full_name, avatarURLString: dto.profile_photo_url, rating: nil, distanceKm: nil)
                }
                return
            }
            
            if let profilesData = try? await client
                .from("profiles")
                .select("full_name,avatar_url,rating,distance_km")
                .eq("id", value: ownerId)
                .single()
                .execute()
                .data as? Data {
                
                let dto = try JSONDecoder().decode(ProfilesDTO.self, from: profilesData)
                await MainActor.run { [weak self] in
                    self?.renderOwner(fullName: dto.full_name, avatarURLString: dto.avatar_url, rating: dto.rating, distanceKm: dto.distance_km)
                }
                return
            }
            
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: "Owner", avatarURLString: nil, rating: nil, distanceKm: nil)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.renderOwner(fullName: "Owner", avatarURLString: nil, rating: nil, distanceKm: nil)
            }
        }
    }
    
    func renderOwner(fullName: String?, avatarURLString: String?, rating: Double?, distanceKm: Double?) {
        let name = (fullName?.isEmpty == false) ? fullName! : "Owner"
        ownerNameLabel?.text = name
        
        if let r = rating {
            ownerstarRating?.text = String(format: "★ %.1f", r)
        } else if ownerstarRating?.text?.isEmpty ?? true {
            ownerstarRating?.text = "No rating"
        }
        if let d = distanceKm {
            ownerDistanceLabel?.text = String(format: "%.1f km", d)
        } else if ownerDistanceLabel?.text?.isEmpty ?? true {
            ownerDistanceLabel?.text = "— km"
        }
        
        if let avatar = avatarURLString, !avatar.isEmpty, let url = urlForAvatarPath(avatar) {
            // Find an image view inside ownerAvatarView if that's the container, else attempt to cast
            let targetImageView: UIImageView
            if let iv = ownerAvatarView as? UIImageView {
                targetImageView = iv
            } else {
                // Try to find a UIImageView subview to place avatar
                if let iv = ownerAvatarView?.subviews.compactMap({ $0 as? UIImageView }).first {
                    targetImageView = iv
                } else {
                    // Create one if none exists
                    let iv = UIImageView(frame: ownerAvatarView?.bounds ?? .zero)
                    iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    ownerAvatarView?.addSubview(iv)
                    targetImageView = iv
                }
            }
            UIImageView.rw_loadImage(from: url) { [weak self] img in
                DispatchQueue.main.async {
                    if let img = img {
                        targetImageView.image = img
                        targetImageView.contentMode = .scaleAspectFill
                        targetImageView.clipsToBounds = true
                        self?.ownerAvatarView?.layer.cornerRadius = (self?.ownerAvatarView?.bounds.height ?? 0) / 2
                        self?.ownerAvatarView?.layer.masksToBounds = true
                    } else {
                        self?.renderOwnerInitials(fullName: name)
                    }
                }
            }
        } else {
            renderOwnerInitials(fullName: name)
        }
    }
    
    func renderOwnerInitials(fullName: String) {
        let initials = makeInitials(from: fullName)
        let targetView = ownerAvatarView
        let size = targetView?.bounds.size == .zero || targetView?.bounds.size == nil ? CGSize(width: 60, height: 60) : targetView!.bounds.size
        
        // Ensure we have an image view to show initials image
        let targetImageView: UIImageView
        if let iv = targetView as? UIImageView {
            targetImageView = iv
        } else if let iv = targetView?.subviews.compactMap({ $0 as? UIImageView }).first {
            targetImageView = iv
        } else {
            let iv = UIImageView(frame: targetView?.bounds ?? CGRect(origin: .zero, size: size))
            iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            targetView?.addSubview(iv)
            targetImageView = iv
        }
        
        targetImageView.image = drawInitialsImage(initials: initials, size: size)
        targetImageView.contentMode = .scaleAspectFill
        targetImageView.clipsToBounds = true
        targetView?.layer.cornerRadius = (targetView?.bounds.height ?? 0) / 2
        targetView?.layer.masksToBounds = true
        targetImageView.backgroundColor = .clear
    }
    
    func makeInitials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let first = parts.first?.first.map { String($0).uppercased() } ?? ""
        let last = parts.dropFirst().last?.first.map { String($0).uppercased() } ?? ""
        let combined = first + last
        return combined.isEmpty ? "?" : combined
    }
    
    func drawInitialsImage(initials: String, size: CGSize) -> UIImage? {
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
    
    func urlForAvatarPath(_ path: String) -> URL? {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path)
        } else {
            return StorageURLBuilder.publicFileURL(for: path)
        }
    }
}

// MARK: - Local fallback for UIExtension.applyGlassEffect
private extension UIView {
    /// Lightweight glass effect to replace missing UIExtension.applyGlassEffect
    func rw_applyGlassEffect(
        cornerRadius: CGFloat = 16,
        style: UIBlurEffect.Style = .systemMaterial,
        addsVibrancy: Bool = false,
        showsShadow: Bool = true,
        borderAlpha: CGFloat = 0.2,
        tintColorOverride: UIColor? = nil,
        tintAlpha: CGFloat = 0.12,
        showsHighlight: Bool = false,
        highlightAlpha: CGFloat = 0.12
    ) {
        // Corner radius & clipping
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false
        // Remove existing blur/vibrancy subviews if reapplying
        subviews.filter { $0.tag == 987654 }.forEach { $0.removeFromSuperview() }

        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.tag = 987654
        blurView.isUserInteractionEnabled = false
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)
        sendSubviewToBack(blurView)

        // Optional vibrancy layer
        if addsVibrancy {
            let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
            vibrancyView.frame = blurView.bounds
            vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.contentView.addSubview(vibrancyView)
        }

        // Subtle tint overlay to simulate material tinting
        if let tint = tintColorOverride {
            let tintView = UIView(frame: bounds)
            tintView.tag = 987654
            tintView.backgroundColor = tint.withAlphaComponent(tintAlpha)
            tintView.isUserInteractionEnabled = false
            tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(tintView)
            sendSubviewToBack(tintView)
        }

        // Border (hairline) to improve contrast on light backgrounds
        if borderAlpha > 0 {
            layer.borderColor = UIColor.label.withAlphaComponent(borderAlpha * 0.15).cgColor
            layer.borderWidth = 0.5
        } else {
            layer.borderWidth = 0
        }

        // Shadow
        if showsShadow {
            layer.shadowColor = UIColor.black.cgColor
            if layer.shadowOpacity == 0 { layer.shadowOpacity = 0.10 }
            if layer.shadowRadius == 0 { layer.shadowRadius = 6 }
            if layer.shadowOffset == .zero { layer.shadowOffset = CGSize(width: 0, height: 4) }
        } else {
            layer.shadowOpacity = 0
        }

        // Optional highlight overlay (top sheen)
        if showsHighlight {
            let highlight = CAGradientLayer()
            highlight.colors = [
                UIColor.white.withAlphaComponent(highlightAlpha).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ]
            highlight.startPoint = CGPoint(x: 0.5, y: 0.0)
            highlight.endPoint = CGPoint(x: 0.5, y: 1.0)
            highlight.frame = bounds
            highlight.cornerRadius = cornerRadius
            highlight.masksToBounds = true
            highlight.name = "glassHighlightLayer"

            // Remove existing highlight
            layer.sublayers?.removeAll(where: { $0.name == "glassHighlightLayer" })
            layer.insertSublayer(highlight, at: 0)
        } else {
            layer.sublayers?.removeAll(where: { $0.name == "glassHighlightLayer" })
        }
    }
}
