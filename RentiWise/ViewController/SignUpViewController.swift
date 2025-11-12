//
//  SignUpViewController.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import UIKit

class SignUpViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "AppStarting", bundle: nil)
        let tabBarVC = storyboard.instantiateViewController(withIdentifier: "NavigationBar")
        
        // Preferred: present it full screen so it replaces the sign-in flow visually.
        tabBarVC.modalPresentationStyle = .fullScreen
        present(tabBarVC, animated: true, completion: nil)
    }
    
   
    @IBAction func signinSwitch(_ sender: UIButton) {
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
    
}
