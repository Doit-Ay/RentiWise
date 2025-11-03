//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.
//

import UIKit

class HomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Additional setup if needed
        title = "" // ensure no title is shown if the bar ever appears
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar when this view controller appears
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore the navigation bar for the next controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
