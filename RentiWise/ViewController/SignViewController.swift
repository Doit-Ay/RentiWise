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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "forgotPassword")
        navigationController?.pushViewController(vc, animated: true)
    }
    
    /*
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Configure destination if needed.
    }
    */
}
