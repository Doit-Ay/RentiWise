//
//  ViewController.swift
//  RentiWise
//
//  Created by admin99 on 18/10/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            // For iOS 13 and earlier, use an empty-titled back button item
            let backItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            navigationItem.backBarButtonItem = backItem
        }

        // Optional: if you also don’t want a title on this root screen
        title = ""
    }

    @IBAction func signInTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SignViewController") as! SignViewController
        // Ensure the destination doesn’t show a title
        vc.title = ""
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SignUpViewController") as! SignUpViewController
        // Ensure the destination doesn’t show a title
        vc.title = ""
        navigationController?.pushViewController(vc, animated: true)
    }
}
