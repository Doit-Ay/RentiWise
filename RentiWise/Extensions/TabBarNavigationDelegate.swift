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

        let isRoot = navigationController.viewControllers.count <= 1
        let tabBar = navigationController.tabBarController?.tabBar
        let shouldHide = !isRoot

        // Only mutate isHidden when the value actually changes.
        // Setting tabBar.isHidden unconditionally triggers a full-window layout pass
        // on every transition, which blocks the push animation on the main thread.
        if tabBar?.isHidden != shouldHide {
            tabBar?.isHidden = shouldHide
        }

        // UIKit already handles hidesBottomBarWhenPushed natively,
        // so only force the property when it needs correcting.
        if viewController.hidesBottomBarWhenPushed != shouldHide {
            viewController.hidesBottomBarWhenPushed = shouldHide
        }
    }
}
