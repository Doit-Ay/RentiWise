//
//  DashboardViewController.swift
//  RentiWise
//
//  Created by admin99 on 06/11/25.


import UIKit

class DashboardViewController: UIViewController, UITabBarDelegate {

    // MARK: - Outlets
    @IBOutlet weak var roleSegmented: UISegmentedControl!
    @IBOutlet weak var contentContainer: UIView!
    
    // MARK: - Properties
    private var currentChildView: UIView?
    
    // Cached content views to avoid reloading NIBs and to preserve state
    private var lenderInstance: LenderView?
    private var borrowerInstance: BorrowerView?
    
    // Guard to prevent duplicate pushes when Add is tapped rapidly
    private var isPushingAddItem = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        navigationController?.navigationBar.tintColor = .label
        
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }

        // Default selection: show Lender on load
        roleSegmented.selectedSegmentIndex = 0
        showLenderView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Reset duplicate-push guard whenever dashboard appears again
        isPushingAddItem = false
    }

    // MARK: - Segmented Control Action
    @IBAction func roleChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            showLenderView()
        } else {
            showBorrowerView()
        }
    }

    // MARK: - Private Helper Methods
    private func showLenderView() {
        if let cached = lenderInstance {
            // Ensure delegate is still set
            cached.delegate = self
            replaceContent(with: cached)
        } else {
            let lender = LenderView()           // Loads LenderView.xib automatically via commonInit
            lender.delegate = self              // Set delegate so we can handle actions
            lenderInstance = lender
            replaceContent(with: lender)
        }
    }

    private func showBorrowerView() {
        if let cached = borrowerInstance {
            replaceContent(with: cached)
        } else {
            let borrower = BorrowerView()
            borrowerInstance = borrower
            replaceContent(with: borrower)
        }
    }

    private func replaceContent(with newView: UIView) {
        // Remove existing child view if any
        currentChildView?.removeFromSuperview()

        // Add new view to container
        newView.translatesAutoresizingMaskIntoConstraints = false
        newView.alpha = 0
        contentContainer.addSubview(newView)

        // Constrain to fill the container
        NSLayoutConstraint.activate([
            newView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            newView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            newView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            newView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        // Crossfade for smoother UX
        UIView.animate(withDuration: 0.22) {
            newView.alpha = 1
        }

        currentChildView = newView
    }
}

// MARK: - LenderViewDelegate
extension DashboardViewController: LenderViewDelegate {
    func lenderView(_ lenderView: LenderView, didSelectInnerIndex index: Int) {
        // Handle Lender inner segmented changes (optional)
        switch index {
        case 0:
            print("LenderView → Listing selected")
        case 1:
            print("LenderView → Request selected")
        case 2:
            print("LenderView → History selected")
        default:
            break
        }
    }

    func lenderViewDidTapAddButton(_ lenderView: LenderView) {
        // Prevent duplicate pushes and ensure we're on top
        guard presentedViewController == nil else { return }
        guard navigationController?.topViewController is DashboardViewController else { return }
        guard !isPushingAddItem else { return }
        isPushingAddItem = true
        
        // Instantiate XIB-backed AddItemFirstViewController
        let vc = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
        vc.title = "Add item"
        // Ensure tab bar hides when pushed
        vc.hidesBottomBarWhenPushed = true

        // Prefer pushing via navigation controller
        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: false)
            nav.pushViewController(vc, animated: true)
        } else {
            // Fallback: present modally and ensure full screen so no tab bar shows
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    

    /*
    // MARK: - Navigation

    
    */

}
