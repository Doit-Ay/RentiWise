import UIKit

class SomeViewController: UIViewController {
    var selectedItem: Item?

    @IBAction func didTapRentNow(_ sender: UIButton) {
        let requestVC = RequestViewController()
        if let item = self.selectedItem {
            requestVC.configure(with: item)
        } else if let id = self.selectedItem?.id {
            requestVC.configure(withItemId: id)
        }
        if let navigationController = self.navigationController {
            navigationController.pushViewController(requestVC, animated: true)
        } else {
            self.present(requestVC, animated: true, completion: nil)
        }
    }
}
