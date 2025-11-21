//
//  RequestSentPageViewController.swift
//  ProductDetails
//
//  Created by user@48 on 18/11/25.
//

import UIKit

class RequestSentPageViewController: UIViewController {
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cards: [UIView?] = [rentalItemCardView, rentalIteminsideView, bookingPeriodCardView, ownerCardView, priceBreakdownCardView]
        cards.forEach { card in
            card?.layer.cornerRadius = 12
            card?.layer.masksToBounds = true
        }
        
        CircleView.layer.cornerRadius = CircleView.bounds.height / 2
        CircleView.layer.masksToBounds = true
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
