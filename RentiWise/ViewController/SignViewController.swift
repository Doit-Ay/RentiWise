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
        // Instantiate HomeViewController from the "AppStarting" storyboard and push it.
        let storyboard = UIStoryboard(name: "AppStarting", bundle: nil)
        // If you prefer to be explicit about the type, you can cast to HomeViewController
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController else {
            assertionFailure("Could not instantiate HomeViewController from AppStarting storyboard. Check Storyboard ID and class.")
            return
        }
        // Optional: clear title if you don’t want it shown on the next screen
        homeVC.title = ""
        
        if let nav = navigationController {
            nav.pushViewController(homeVC, animated: true)
        } else {
            // Fallback if not embedded in a navigation controller: present modally
            homeVC.modalPresentationStyle = .fullScreen
            present(homeVC, animated: true, completion: nil)
        }
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
