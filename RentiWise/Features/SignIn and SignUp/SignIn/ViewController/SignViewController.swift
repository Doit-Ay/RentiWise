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
        // Safely instantiate Forgot Password screen from the "Sign" storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier = "forgotPassword"
        let vc = storyboard.instantiateViewController(withIdentifier: identifier)

        // Prefer pushing if we're inside a navigation controller; otherwise present modally
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
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
        
    }
    
    
    @IBAction func forgetContinue(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier = "SignViewController"
        let vc = storyboard.instantiateViewController(withIdentifier: identifier)

        // Prefer pushing if we're inside a navigation controller; otherwise present modally
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }

    }
    
    
    @IBAction func signupSwitch(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier = "SignUpViewController"
        let vc = storyboard.instantiateViewController(withIdentifier: identifier)
        
        // Prefer pushing if we're inside a navigation controller; otherwise present modally
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
    
}
