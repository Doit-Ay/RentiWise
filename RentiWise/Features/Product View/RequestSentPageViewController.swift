//
//  RequestSentPageViewController.swift
//  ProductDetails
//
//  Created by user@48 on 18/11/25.
//

import UIKit

class RequestSentPageViewController: UIViewController {
    
    var item: Item?
    
    // State for pricing mode and booking
    private enum RentalUnit { case perHour, perDay }
    private var rentalUnit: RentalUnit = .perDay { didSet { updatePriceLabels() } }

    // Inputs for booking summary (set these from previous screen)
    var bookingStartDate: Date?
    var bookingEndDate: Date?
    var pickupTime: Date?
    
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
    }
    
    func configure(with item: Item) {
        self.item = item
        if isViewLoaded { updateUI() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cards: [UIView?] = [rentalItemCardView, rentalIteminsideView, bookingPeriodCardView, ownerCardView, priceBreakdownCardView]
        cards.forEach { card in
            card?.layer.cornerRadius = 16
            card?.layer.masksToBounds = true
        }
        
        CircleView.layer.cornerRadius = CircleView.bounds.height / 2
        CircleView.layer.masksToBounds = true
        
        // Apply glass effect to primary cards for visual consistency
        rentalItemCardView?.applyGlassEffectSimple()
        bookingPeriodCardView?.applyGlassEffectSimple()
        ownerCardView?.applyGlassEffectSimple()
        priceBreakdownCardView?.applyGlassEffectSimple()
        
        // Initialize toggle visual state
        updateToggleUI()
        
        updateUI()
    }
    
    @IBAction func didTapPerHour(_ sender: UIButton) {
        rentalUnit = .perHour
        updateToggleUI()
    }

    @IBAction func didTapPerDay(_ sender: UIButton) {
        rentalUnit = .perDay
        updateToggleUI()
    }
    
    private func updateUI() {
        guard let item = item else { return }

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
                }
            }
        } else {
            productThumbImageView?.image = nil
        }

        // Rental unit label
        rentalLabel?.text = "Per day"

        // Update pricing labels based on selected unit
        updatePriceLabels()

        // Booking summary
        if let start = bookingStartDate {
            bookingdateLabel?.text = dateFormatter.string(from: start)
            bookingPickupTimeLabel?.text = timeFormatter.string(from: start)
        } else {
            bookingdateLabel?.text = "—"
            bookingPickupTimeLabel?.text = "—"
        }
        if let end = bookingEndDate {
            // show end time as return time
            pickuptimeLabel?.text = timeFormatter.string(from: end)
        } else {
            pickuptimeLabel?.text = "—"
        }
        if let start = bookingStartDate, let end = bookingEndDate {
            let duration = end.timeIntervalSince(start)
            let hours = max(0, Int(duration / 3600))
            let days = max(0, Int(ceil(duration / 86400)))
            bookingDurationLabel?.text = rentalUnit == .perHour ? "\(hours)h" : "\(days)d"
            bookingDateRangeLabel?.text = "\(dateFormatter.string(from: start)) — \(dateFormatter.string(from: end))"
        } else {
            bookingDurationLabel?.text = "—"
            bookingDateRangeLabel?.text = "—"
        }

        // Owner fallbacks (populate when you have real owner data)
        ownerNameLabel?.text = ownerNameLabel?.text?.isEmpty == false ? ownerNameLabel?.text : "Owner Name"
        ownerstarRating?.text = ownerstarRating?.text?.isEmpty == false ? ownerstarRating?.text : "Rating"
        ownerDistanceLabel?.text = ownerDistanceLabel?.text?.isEmpty == false ? ownerDistanceLabel?.text : "Distance"
    }
    
    private func updatePriceLabels() {
        guard let item = item else { return }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        // Compute unit price
        let perDay = item.price_per_day
        let perHour = perDay / 24.0
        let unitPrice = (rentalUnit == .perHour) ? perHour : perDay

        // Total/rental fee based on duration if both dates exist; else show unit price
        var total = unitPrice
        if let start = bookingStartDate, let end = bookingEndDate, end > start {
            let duration = end.timeIntervalSince(start)
            if rentalUnit == .perHour {
                let hours = duration / 3600.0
                total = perHour * max(1.0, ceil(hours))
            } else {
                let days = duration / 86400.0
                total = perDay * max(1.0, ceil(days))
            }
        }

        let unitText = formatter.string(from: NSNumber(value: unitPrice)) ?? String(format: "%.2f", unitPrice)
        let totalText = formatter.string(from: NSNumber(value: total)) ?? String(format: "%.2f", total)
        rentalLabel?.text = (rentalUnit == .perHour) ? "Per hour" : "Per day"
        rentalFeeAmountLabel?.text = unitText
        totalAmountLabel?.text = totalText

        // Security deposit
        let depositText = formatter.string(from: NSNumber(value: item.deposit_amount)) ?? String(format: "%.2f", item.deposit_amount)
        securityDepositAmountLabel?.text = depositText
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
    
    @IBAction func gotodashboardbuttonTapped(_ sender: Any) {
        // Simple, deterministic route: reset root to AppStarting → NavigationBar,
        // then make DashboardListing the visible controller.
        let sb = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
        let root = sb.instantiateViewController(withIdentifier: Constants.navigationBarID)
        let dashboard = instantiateDashboardListing()
        
        // Configure Dashboard to show Borrower before it becomes visible.
        if let dashboardVC = dashboard as? DashboardViewController {
            // Option A: If DashboardViewController exposes a method
            // dashboardVC.showBorrowerView()
            
            // Option B: If you control the segmented control directly
            // Replace `borrowerIndex` with the actual index for the Borrower segment (e.g., 1)
            // dashboardVC.segmentedControl.selectedSegmentIndex = borrowerIndex
            // dashboardVC.segmentedControl.sendActions(for: .valueChanged)
            
            // Option C: If Dashboard supports an initial mode/index property
            // dashboardVC.initialSelectedIndex = borrowerIndex
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = root
            window.makeKeyAndVisible()
            
            if let nav = root as? UINavigationController {
                nav.setViewControllers([dashboard], animated: false)
            } else if let tabBar = root as? UITabBarController {
                // If your app uses a tab bar, select the tab that hosts Dashboard (adjust index if needed).
                // If Dashboard is on a specific tab, set selectedIndex accordingly.
                // Example: borrower tab is index 0
                let dashboardTabIndex = tabBar.viewControllers?.firstIndex(where: { vc in
                    if let nav = vc as? UINavigationController {
                        return type(of: nav.viewControllers.first ?? UIViewController()) == type(of: dashboard)
                    }
                    return type(of: vc) == type(of: dashboard)
                }) ?? tabBar.selectedIndex
                
                if dashboardTabIndex < (tabBar.viewControllers?.count ?? 0) {
                    tabBar.selectedIndex = dashboardTabIndex
                    if let nav = tabBar.selectedViewController as? UINavigationController {
                        nav.setViewControllers([dashboard], animated: false)
                    } else {
                        let nav = UINavigationController(rootViewController: dashboard)
                        var vcs = tabBar.viewControllers ?? []
                        if dashboardTabIndex < vcs.count {
                            vcs[dashboardTabIndex] = nav
                            tabBar.setViewControllers(vcs, animated: false)
                            tabBar.selectedIndex = dashboardTabIndex
                        } else {
                            tabBar.present(nav, animated: true)
                        }
                    }
                } else {
                    let nav = UINavigationController(rootViewController: dashboard)
                    nav.modalPresentationStyle = .fullScreen
                    tabBar.present(nav, animated: true)
                }
            } else {
                dashboard.modalPresentationStyle = .fullScreen
                root.present(dashboard, animated: true)
            }
        } else {
            // Fallback if we can’t access the window; just present
            dashboard.modalPresentationStyle = .fullScreen
            present(dashboard, animated: true)
        }
    }
}

