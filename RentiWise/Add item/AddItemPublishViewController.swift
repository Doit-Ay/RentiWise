//
//  AddItemPublishViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit

class AddItemPublishViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        title = ""
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
    }

    @IBAction func PublishTapped(_ sender: UIButton) {
        // Dismiss keyboard or any editing before transition
        view.endEditing(true)

        let storyboard = UIStoryboard(name: "AppStarting", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DashboardListing")

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
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
