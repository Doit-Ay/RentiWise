import UIKit

class PriceAnalyzerScreenOneViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if title?.isEmpty ?? true {
            title = "Price Analyzer"
        }
    }

    @IBAction func analyzePrice(_ sender: UIButton) {
        // Instantiate from XIB; ensure a XIB named "PriceAnalyzerScreenTwoViewController.xib" exists
        let vc = PriceAnalyzerScreenTwoViewController(nibName: "PriceAnalyzerScreenTwoViewController", bundle: nil)
        vc.title = "Analyze Result"
        vc.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            // If we're already in a navigation stack, push and ensure the bar is visible
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            // Fallback: present modally but wrap in a navigation controller so title/back appear
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}
