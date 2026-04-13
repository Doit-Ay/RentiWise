//
//  AppDelegate.swift
//  RentiWise
//
//  Created by admin99 on 18/10/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Start preloading immediately (while launch screen is still showing)
        PreloadManager.shared.startPreloading()
        // Notification permission is requested lazily when the first rental
        // reminder needs to be scheduled (Apple Guideline 5.1.2 — TC-PR03).
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Release any resources that were specific to the discarded scenes.
    }
}
