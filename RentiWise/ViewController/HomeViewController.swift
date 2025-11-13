//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.
//

import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITabBarDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet var productclicked: UIView!
    @IBOutlet var ProfileImageTapped: UIImageView!
    
    private struct CategoryItem {
        let title: String
        let systemImageName: String
    }

    // Configure your categories here (using SF Symbols)
    private let categories: [CategoryItem] = [
        .init(title: "Electronics", systemImageName: "drone"), // pick your preferred symbol
        .init(title: "Tools",       systemImageName: "hammer"),
        .init(title: "Events",      systemImageName: "hifispeaker"),
        .init(title: "Fitness",     systemImageName: "dumbbell"),
        // Add more if you want to scroll
        .init(title: "Hobbies",      systemImageName: "guitars"),
        .init(title: "Outdoor",       systemImageName: "tent"),
//        .init(title: "Books",       systemImageName: "book"),
//        .init(title: "Cameras",     systemImageName: "camera")
    ]

    // Desired tint color (#70A7B4)
    private let categoryIconTintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        navigationController?.navigationBar.tintColor = .label
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
        
        // Collection view setup
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Ensure only horizontal bounce/scrolling feel
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        
        // Apply horizontal layout to show 4 items across
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
        
        // Setup tap on profile image
        setupProfileImageTap()
        
        // Setup tap on product card/view to open ProductViewController
        setupProductTap()
        
        // Tab bar setup
        
        
        // If you created items in Interface Builder, this is optional.
        // If you want to create items in code instead, uncomment and customize:
        /*
         let homeItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
         let dashboardItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar"), selectedImage: UIImage(systemName: "chart.bar.fill"))
         // Optional: use tags to identify items instead of titles
         homeItem.tag = 0
         dashboardItem.tag = 1
         TabBar.items = [homeItem, dashboardItem]
         TabBar.selectedItem = homeItem
         */
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Re-apply layout on rotation/safe area change to keep 4-up sizing correct
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
    }
    
    // MARK: - Profile tap setup
    private func setupProfileImageTap() {
        // Ensure the outlet is connected
        guard let imageView = ProfileImageTapped else { return }
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapProfileImage))
        imageView.addGestureRecognizer(tap)
        // Optional: accessibility
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Profile"
        imageView.accessibilityTraits = .button
    }
    
    // MARK: - Product tap setup
    private func setupProductTap() {
        guard let productView = productclicked else { return }
        productView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapProductView))
        productView.addGestureRecognizer(tap)
        // Optional accessibility
        productView.isAccessibilityElement = true
        productView.accessibilityLabel = "Product details"
        productView.accessibilityTraits = .button
    }
    
    @objc private func didTapProfileImage() {
        // Instantiate from XIB named "ProfileMainViewController.xib"
        let vc = ProfileMainViewController(nibName: "ProfileMainViewController", bundle: nil)
        vc.title = "Profile"
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
    
    @objc private func didTapProductView() {
        // Instantiate ProductViewController from XIB if available, else fallback to code
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.title = "Product Detail"
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = .fullScreen
            present(productVC, animated: true)
        }
    }

    // MARK: - Compositional Layout: Horizontal row, 4 items visible per page
    private func generateHorizontalFourUpLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (_, environment) -> NSCollectionLayoutSection? in

            let interItemSpacing: CGFloat = 10
            let contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

            // Each item is 1/4 of the group's width and full group height
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.25),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                         leading: interItemSpacing / 2,
                                                         bottom: 0,
                                                         trailing: interItemSpacing / 2)

            // Height for the row (tweak as needed)
            let rowHeight: CGFloat = 70

            // Group spans the full width so that 4 items are visible per "page"
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(rowHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = contentInsets

            // Snap page-by-page so each page shows exactly 4 items
            section.orthogonalScrollingBehavior = .groupPaging

            return section
        }
        return layout
    }

    // MARK: - Simple push helper
    private func pushCategories(title: String) {
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "Categories")
        vc.title = title
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Ensure the reuse identifier on the storyboard cell matches this string
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Category", for: indexPath) as? CategoryCollectionViewCell else {
            assertionFailure("Could not dequeue CategoryCollectionViewCell with identifier 'Category'")
            return UICollectionViewCell()
        }

        let item = categories[indexPath.item]
        cell.categoryLabel.text = item.title

        // Configure SF Symbol with preferred size/weight
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular, scale: .medium)
        cell.categoryImage.preferredSymbolConfiguration = config
        cell.categoryImage.image = UIImage(systemName: item.systemImageName)

        // Apply requested tint color #70A7B4
        cell.categoryImage.tintColor = categoryIconTintColor

        // Optional styling
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        cell.contentView.backgroundColor = UIColor.white

        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = categories[indexPath.item]
        pushCategories(title: item.title)
    }

    // MARK: - UITabBarDelegate
    
    
}
