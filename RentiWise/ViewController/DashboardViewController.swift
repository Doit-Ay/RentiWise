//
//  DashboardViewController.swift
//  RentiWise
//
//  Created by admin99 on 06/11/25.


import UIKit

class DashboardViewController: UIViewController, UITabBarDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        navigationController?.navigationBar.tintColor = .label
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
        
    

        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    @IBAction func Additem(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "AppStarting", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AddItemViewController") as? AddItemViewController else {
            assertionFailure("Storyboard ID 'AddItemViewController' not found or wrong class.")
            return
        }
        vc.title = "Add item"

        guard let nav = navigationController else {
            assertionFailure("DashboardViewController is not embedded in a UINavigationController. Embed it to enable push navigation.")
            return
        }

        // If you hide the navigation bar on this screen, you may want it visible on the next screen
        nav.setNavigationBarHidden(false, animated: false)

        // Instant navigation (no animation)
        nav.pushViewController(vc, animated: false)
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
