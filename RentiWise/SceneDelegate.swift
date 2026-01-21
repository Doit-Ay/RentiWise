//
//  SceneDelegate.swift
//  RentiWise
//
//  Created by admin99 on 18/10/25.
//

import UIKit
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // Keep a strong ref to the overlay so we can dismiss it
    private var noInternetOverlay: UIViewController?

    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
    }

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Kick off preloading as the scene connects (while the launch screen is still visible)
        PreloadManager.shared.startPreloading()

        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let storyboard = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
        let rootVC = storyboard.instantiateViewController(withIdentifier: Constants.navigationBarID)

        window.rootViewController = rootVC
        window.makeKeyAndVisible()

        // Start network monitoring and show initial state if needed
        _ = NetworkMonitor.shared
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectivityChange), name: .networkConnectivityChanged, object: nil)

        // Apply initial state right away on main
        DispatchQueue.main.async { [weak self] in
            self?.applyConnectivityOverlay(isConnected: NetworkMonitor.shared.isConnected)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}

    @objc private func handleConnectivityChange() {
        // Hop to main before touching UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applyConnectivityOverlay(isConnected: NetworkMonitor.shared.isConnected)
        }
    }

    private func applyConnectivityOverlay(isConnected: Bool) {
        // This method is only called on main (see callers)
        guard let window = window else { return }

        if isConnected {
            // Dismiss overlay if shown
            if let overlay = noInternetOverlay {
                overlay.dismiss(animated: true)
                noInternetOverlay = nil
            }
            return
        }

        // Already showing
        if noInternetOverlay != nil { return }

        let overlay = NoInternetViewController()
        overlay.modalPresentationStyle = .overFullScreen
        overlay.modalTransitionStyle = .crossDissolve
        overlay.onRetry = { [weak self] in
            // Re-evaluate on main
            DispatchQueue.main.async {
                // If network is back, this will dismiss. If still offline, it will keep showing.
                self?.applyConnectivityOverlay(isConnected: NetworkMonitor.shared.isConnected)
            }
        }

        // Present on top of the current top-most controller
        let presenter = topViewController(from: window.rootViewController) ?? window.rootViewController
        presenter?.present(overlay, animated: true)
        noInternetOverlay = overlay
    }

    private func topViewController(from base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }
}
