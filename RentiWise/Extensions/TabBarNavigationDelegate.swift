//
//  TabBarNavigationDelegate.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit

/// Global navigation delegate that automatically hides the tab bar when pushing view controllers
class TabBarNavigationDelegate: NSObject, UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, 
                            willShow viewController: UIViewController, 
                            animated: Bool) {
        
        // Get the view controllers in the navigation stack
        let viewControllers = navigationController.viewControllers
        
        // If this is the root view controller (only one in stack), show the tab bar
        // Otherwise, hide it
        if viewControllers.count <= 1 {
            viewController.hidesBottomBarWhenPushed = false
            navigationController.tabBarController?.tabBar.isHidden = false
        } else {
            viewController.hidesBottomBarWhenPushed = true
            navigationController.tabBarController?.tabBar.isHidden = true
        }
    }
}
