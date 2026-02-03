//
//  TabBarNavigationDelegate.swift
//  RentiWise
//
//  Created by Antigravity on 04/02/26.
//

import UIKit
import SwiftUI

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

// MARK: - SwiftUI Tab Bar Hiding

/// A SwiftUI view modifier that hides the tab bar when the view appears
struct HideTabBar: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                hideTabBar()
            }
    }
    
    private func hideTabBar() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let tabBarController = window.rootViewController as? UITabBarController {
                tabBarController.tabBar.isHidden = true
            }
        }
    }
}

extension View {
    /// Hides the tab bar when this view appears (restored by root screens)
    func hideTabBar() -> some View {
        modifier(HideTabBar())
    }
}
