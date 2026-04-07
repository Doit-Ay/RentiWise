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
            
            let backItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            navigationItem.backBarButtonItem = backItem
        }

        // Optional: if you also don’t want a title on this root screen
        title = ""
    }

    @IBAction func signInTapped(_ sender: UIButton) {
        openAuthScreen(.signIn(routeContext: .default))
    }
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        openAuthScreen(.signUp)
    }
    
}
