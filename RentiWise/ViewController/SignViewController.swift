//
//  SignViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit

class SignViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    @IBAction func forgotPassword(_ sender: UIButton) {
        let vc = UIStoryboard(name: "Sign", bundle: nil).instantiateViewController(withIdentifier: "forgotPassword")
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    @IBAction func signInProceed(_ sender: UIButton) {
        // Instantiate the Tab Bar Controller (not the HomeViewController).
        // Storyboard: "AppStarting"
        // Tab bar controller storyboard ID: "NavigationBar"
        let storyboard = UIStoryboard(name: "AppStarting", bundle: nil)
        let tabBarVC = storyboard.instantiateViewController(withIdentifier: "NavigationBar")
        
        // Preferred: present it full screen so it replaces the sign-in flow visually.
        tabBarVC.modalPresentationStyle = .fullScreen
        present(tabBarVC, animated: true, completion: nil)
        
        // If you instead want it to become the new root (cleaner app state),
        // uncomment this block and remove the present(...) above.
        /*
        if let scene = view.window?.windowScene {
            let window = UIWindow(windowScene: scene)
            window.rootViewController = tabBarVC
            window.makeKeyAndVisible()
            // Assign to SceneDelegate so it’s retained
            if let sceneDelegate = scene.delegate as? SceneDelegate {
                sceneDelegate.window = window
            }
        } else {
            // Fallback to presenting full screen if windowScene is not available
            tabBarVC.modalPresentationStyle = .fullScreen
            present(tabBarVC, animated: true, completion: nil)
        }
        */
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
