//
//  AddItemPublishViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPublishViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
    }

    @IBAction func PublishTapped(_ sender: UIButton) {
        view.endEditing(true)

        // 1) Get the current tab bar controller from the window hierarchy
        // This avoids presenting a dashboard outside of the tab bar.
        guard let tabBar = (view.window?.rootViewController as? UITabBarController)
                ?? navigationController?.tabBarController
                ?? tabBarController
        else {
            // As a fallback, just pop/dismiss to reveal whatever is underneath
            if presentingViewController != nil || navigationController?.presentingViewController != nil {
                dismiss(animated: true)
            } else {
                navigationController?.popToRootViewController(animated: true)
            }
            return
        }

        // 2) Instantiate DashboardListing from "AppStarting"
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        let dashboard = sb.instantiateViewController(withIdentifier: "DashboardListing")
        dashboard.hidesBottomBarWhenPushed = false

        // 3) Decide which tab should show the dashboard.
        // If your dashboard is on a specific tab, select it here. Adjust index as needed.
        // For example, if Dashboard is tab index 1:
        let dashboardTabIndex = 1
        if dashboardTabIndex < (tabBar.viewControllers?.count ?? 0) {
            tabBar.selectedIndex = dashboardTabIndex
        }

        // 4) Ensure we push inside the selected tab’s navigation controller.
        if let nav = tabBar.selectedViewController as? UINavigationController {
            // Replace the stack with the dashboard so previous hidesBottomBarWhenPushed state can’t carry over.
            nav.setViewControllers([dashboard], animated: true)
        } else if let selectedVC = tabBar.selectedViewController {
            // Embed a temporary navigation controller if the selected tab isn’t a nav controller
            let nav = UINavigationController(rootViewController: dashboard)
            nav.modalPresentationStyle = .fullScreen
            // Replace the selected tab controller entirely (safer to configure tabs in storyboard as navs)
            var vcs = tabBar.viewControllers ?? []
            if dashboardTabIndex < vcs.count {
                vcs[dashboardTabIndex] = nav
                tabBar.setViewControllers(vcs, animated: false)
                tabBar.selectedIndex = dashboardTabIndex
            } else {
                // Fallback: present within tab, but this is not ideal
                selectedVC.present(nav, animated: true)
            }
        }
    }
}
