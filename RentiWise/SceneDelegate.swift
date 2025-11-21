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

    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let storyboard = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
        let rootVC = storyboard.instantiateViewController(withIdentifier: Constants.navigationBarID)

        window.rootViewController = rootVC
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
