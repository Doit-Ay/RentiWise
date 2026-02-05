//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.

import UIKit
import Supabase

class HomeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITabBarDelegate, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var greetingTop: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var Homepagelastline: UILabel!
    @IBOutlet var productclicked: UIView!
    // Single image outlet only
    @IBOutlet weak var homeimage: UIImageView!

    @IBAction func seeAllTrending(_ sender: UIButton) {
    }
    @IBOutlet weak var trendingUiView: UIView!
    @IBOutlet weak var locationTapped: UIButton!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var homeBG: UIView!
    
    // Keep a reference so we can resize and avoid duplicates
    // private var homeGradientLayer: CAGradientLayer?

    @IBAction func notificationBellTapped(_ sender: UIButton) {
        let nibName = "NotificationViewController"
        let vc: NotificationViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = NotificationViewController(nibName: nibName, bundle: nil)
        } else {
            vc = NotificationViewController()
        }
        vc.title = "Notifications"
        vc.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    @IBOutlet weak var notificationBell: UIButton!
    @IBOutlet weak var listingUIView: UIView!
    @IBOutlet weak var additemHome: UIButton!
    @IBOutlet weak var startearninglabel: UILabel!
    @IBOutlet weak var startearningdownlabel: UILabel!
    
    // Home screen “Request” button → push RequestsListViewController (no Dashboard)
    @IBAction func requestsButtonTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // Require login for Requests
                let session = try await SupabaseManager.shared.client.auth.session
                _ = session.user // throws if not logged in

                let vc = RequestsListViewController()
                vc.title = "Requests"
                vc.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(vc, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            } catch {
                // Not logged in -> open Sign In
                let nibName = "SignViewController"
                let signInVC: SignViewController
                if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                    Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                    signInVC = SignViewController(nibName: nibName, bundle: nil)
                } else {
                    signInVC = SignViewController(service: SignInService())
                }
                signInVC.routeContext = .default
                signInVC.title = "Sign in"
                signInVC.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(signInVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: signInVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
        }
    }
    
    @IBAction func additemHomeTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // Check if the user is logged in
                let session = try await SupabaseManager.shared.client.auth.session
                _ = session.user // throws if not logged in

                // Logged in -> start Add Item flow
                let vc = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
                vc.title = "Add item"
                vc.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: false)
                    nav.pushViewController(vc, animated: true)
                } else {
                    vc.modalPresentationStyle = .fullScreen
                    self.present(vc, animated: true)
                }
            } catch {
                // Not logged in -> open Sign In
                let nibName = "SignViewController"
                let signInVC: SignViewController
                if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                    Bundle.main.path(forResource: "SignViewController", ofType: "xib") != nil {
                    signInVC = SignViewController(nibName: nibName, bundle: nil)
                } else {
                    signInVC = SignViewController(service: SignInService())
                }
                // If you later want to resume Add Item after login, add a new routeContext case and handle it in SignViewController.
                signInVC.routeContext = .default
                signInVC.title = "Sign in"
                signInVC.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(signInVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: signInVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
        }
    }
    private struct CategoryItem {
        let title: String
        let systemImageName: String
    }

    private let categories: [CategoryItem] = [
        .init(title: "Electronics", systemImageName: "drone"),
        .init(title: "Tools",       systemImageName: "hammer"),
        .init(title: "Events",      systemImageName: "hifispeaker"),
        .init(title: "Fitness",     systemImageName: "dumbbell"),
        .init(title: "Hobbies",     systemImageName: "guitars"),
        .init(title: "Outdoor",     systemImageName: "tent"),
    ]


    // Desired tint color (#70A7B4)
    private let categoryIconTintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // Currency formatter for rates
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Home header image rotation
    private let rotatingImageNames = ["Home1image", "Home2image", "Home3image"]
    private var imageRotationTimer: Timer?
    private var currentHomeImageIndex = 0
    private let rotationInterval: TimeInterval = 5.0

    // We’ll trigger the first image after layout to ensure bounds are valid
    private var didSetInitialHomeImageAfterLayout = false

    // Hold onto loaded featured items so we can open details on tap
    private var featuredItems: [Item] = []

    // Private containers for round glass buttons in the header
    private var notificationContainer: UIView?

    private var addItemContainer: UIView?

    // MARK: - Manage Listings state
    private var isListingDataLoaded = false // track if listing data has been fetched
    private var manageContainerView: UIView? // inserted inside listingUIView when user has items

    // MARK: - Trending collection (new)
    private var trendingCollectionView: UICollectionView?
    private var trendingItems: [Item] = []

    // Owner name cache for trending items (no longer used for UI, but kept if needed later)
    private var ownerNameCache: [String: String] = [:]

    // MARK: - Search helper
    private var homeSearch: HomeSearchController?

    // MARK: - Services
    private let itemsService = ItemsService()
    
    // MARK: - Navigation delegate for tab bar hiding
    private let tabBarDelegate = TabBarNavigationDelegate()
    
    // MARK: - Notification badge
    private var unreadNotificationCount: Int = 0
    private var notificationBadge: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        navigationController?.navigationBar.tintColor = .label
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }

        // Basic setup
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
        // Make the surrounding area transparent so only tiles are visible
        collectionView.backgroundColor = .clear

        // Style the search bar for a modern rounded look
        styleSearchBar()

        // Ensure the location button truncates within its space
        configureLocationButtonAppearance()

        setupProductTap()
        setupFeaturedItemTaps()

        // Trending scroller inside trendingUiView
        setupTrendingCollection()

        Task { await loadFeaturedItems() }

        // Ensure aspect fit and clipping on the single image view
        homeimage?.contentMode = .scaleAspectFit
        homeimage?.clipsToBounds = true

        // Set a fallback initial image immediately (in case timer/animation is delayed)
        if homeimage?.image == nil, let first = rotatingImageNames.first {
            homeimage?.image = UIImage(named: first)
        }
        
        // Refresh location button title ("SRMIST" if none saved) and ensure a real default is persisted
        refreshLocationButtonTitle()

        // Initialize search helper (rounded search bar, keyboard behavior, inline results)
        if let sb = searchBar {
            let hs = HomeSearchController(searchBar: sb, in: view)
            hs.onSelectItem = { [weak self] item in
                self?.openItem(item)
            }
            self.homeSearch = hs
        }

        // Add a background tap to dismiss keyboard when tapping anywhere outside the search bar/results
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // Set the bottom tagline "You ❤️ RentiWise" with brand-colored heart
        setBottomTagline()
        
        // Set navigation delegate to auto-hide tab bar on push
        navigationController?.delegate = tabBarDelegate
        
        // Ensure tab bar item shows title
        navigationController?.tabBarItem.title = "Explore"
        
        // Initially hide the listing section until data loads to prevent flicker
        listingUIView?.alpha = 0
    }

    @objc private func dismissKeyboardTap() {
        // Resign first responder from the search bar / any field
        view.endEditing(true)
        // Optional: if you want to also hide inline results when dismissing:
        // homeSearch?.clearResults()
        // Keep results table aligned after any layout changes
        homeSearch?.layoutForSearchBarBelow()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Keep the rounded background sized to the search bar's current bounds
        layoutSearchBarRounded()

        // After we know bounds, set initial image once (no animation)
        if !didSetInitialHomeImageAfterLayout {
            didSetInitialHomeImageAfterLayout = true
            updateHomeImage(animated: false)
        }

        // Keep the inline results table pinned under the search bar
        homeSearch?.layoutForSearchBarBelow()

        // Gradient temporarily disabled
        // setupHomeBackgroundGradient()

        // Apply glass to featured cards (once; helper reuses existing blur view by tag)
        applyGlassToFeaturedCardsIfNeeded()
        // Apply glass to Rent buttons
        applyGlassToRentButtonsIfNeeded()
        // Apply round glass containers to notification and add-item buttons
        applyGlassToHeaderRoundButtons()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        // Always show tab bar when Home screen appears
        tabBarController?.tabBar.isHidden = false
        startHomeImageRotation()
        // Update greeting based on time of day
        updateGreeting()
        // Refresh the listing section each time we come back
        Task { await checkAndUpdateListingSection() }
        // Refresh location button on appear as well
        refreshLocationButtonTitle()
        // Update notification badge
        Task { await updateNotificationBadge() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopHomeImageRotation()
    }

    deinit { stopHomeImageRotation() }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
        layoutSearchBarRounded()
    }

    // MARK: - Search bar styling
    private func styleSearchBar() {
        guard let sb = searchBar else { return }

        sb.searchBarStyle = .minimal
        sb.isTranslucent = true
        sb.backgroundColor = .clear
        sb.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        sb.setSearchFieldBackgroundImage(UIImage(), for: .normal)

        // Access searchTextField for deeper styling (iOS 13+)
        let tf = sb.searchTextField
        tf.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        tf.textColor = .label
        tf.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0) // brand teal cursor
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .none
        tf.layer.masksToBounds = false
        // Corner radius will be set in layoutSearchBarRounded() so it adapts to height
        tf.leftView?.tintColor = .tertiaryLabel

        // Placeholder with subtle color
        let placeholder = tf.placeholder ?? "Search items"
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )

        // Add subtle shadow to lift the pill
        tf.layer.shadowColor = UIColor.black.cgColor
        tf.layer.shadowOpacity = 0.08
        tf.layer.shadowRadius = 6
        tf.layer.shadowOffset = CGSize(width: 0, height: 3)

        // The search icon is preserved by default via leftView
        // Cancel button tint to match brand
        sb.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    }

    private func layoutSearchBarRounded() {
        guard let sb = searchBar else { return }
        let tf = sb.searchTextField
        // Corner radius based on current height for a pill shape
        let h = tf.bounds.height > 0 ? tf.bounds.height : 36
        tf.layer.cornerRadius = h / 2

        // Optional thin border for definition on light backgrounds
        tf.layer.borderWidth = 0.5
        tf.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
    }

    // MARK: - Location button text behavior (truncate within given space)
    private func configureLocationButtonAppearance() {
        guard let btn = locationTapped else { return }
        // Keep single line and truncate at tail with ellipsis
        btn.titleLabel?.numberOfLines = 1
        btn.titleLabel?.lineBreakMode = .byTruncatingTail
        btn.titleLabel?.adjustsFontSizeToFitWidth = false
        // Keep text left-aligned within its bounds
        btn.contentHorizontalAlignment = .leading
        // Optional: small horizontal padding
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        // Prefer truncation over expanding horizontally
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        // If the button has an image, ensure room between image and text
        if btn.image(for: .normal) != nil {
            btn.semanticContentAttribute = .forceLeftToRight
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        }
    }

    // MARK: - Product tap setup
    private func setupProductTap() {
        guard let productView = productclicked else { return }
        productView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapProductView))
        productView.addGestureRecognizer(tap)
        productView.isAccessibilityElement = true
        productView.accessibilityLabel = "Product details"
        productView.accessibilityTraits = .button
    }

    private func setupFeaturedItemTaps() {
        // Image taps
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        item1Image?.isUserInteractionEnabled = true
        item1Image?.addGestureRecognizer(tap1)

        let tap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        item2Image?.isUserInteractionEnabled = true
        item2Image?.addGestureRecognizer(tap2)

        let tap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        item3Image?.isUserInteractionEnabled = true
        item3Image?.addGestureRecognizer(tap3)

        let tap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        item4Image?.isUserInteractionEnabled = true
        item4Image?.addGestureRecognizer(tap4)

        // Card taps (make entire card tappable)
        let cardTap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        item1CardView?.isUserInteractionEnabled = true
        item1CardView?.addGestureRecognizer(cardTap1)

        let cardTap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        item2CardView?.isUserInteractionEnabled = true
        item2CardView?.addGestureRecognizer(cardTap2)

        let cardTap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        item3CardView?.isUserInteractionEnabled = true
        item3CardView?.addGestureRecognizer(cardTap3)

        let cardTap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        item4CardView?.isUserInteractionEnabled = true
        item4CardView?.addGestureRecognizer(cardTap4)
    }

    @objc private func didTapFeatured1() { openFeatured(at: 0) }
    @objc private func didTapFeatured2() { openFeatured(at: 1) }
    @objc private func didTapFeatured3() { openFeatured(at: 2) }
    @objc private func didTapFeatured4() { openFeatured(at: 3) }

    private func openFeatured(at index: Int) {
        guard index < featuredItems.count else { return }
        let item = featuredItems[index]
        // Instantiate ProductViewController
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.configure(with: item)
        productVC.title = "Product Detail"
        productVC.hidesBottomBarWhenPushed = true
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = .fullScreen
            present(productVC, animated: true)
        }
    }

    // Helper used by trending list to open an item detail
    private func openItem(_ item: Item) {
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.configure(with: item)
        productVC.title = "Product Detail"
        productVC.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = .fullScreen
            present(productVC, animated: true)
        }
    }
    
    // Helper to open RequestViewController directly from rent button
    private func openRequestView(for item: Item) {
        let nibName = "RequestViewController"
        let requestVC: RequestViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            requestVC = RequestViewController(nibName: nibName, bundle: nil)
        } else {
            requestVC = RequestViewController()
        }
        requestVC.configure(with: item)
        requestVC.title = "Request"
        requestVC.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(requestVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: requestVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
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
        if let first = featuredItems.first { productVC.configure(with: first) }
        productVC.title = "Product Detail"
        productVC.hidesBottomBarWhenPushed = true
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
        let layout = UICollectionViewCompositionalLayout { (_, _) -> NSCollectionLayoutSection? in

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
            let rowHeight: CGFloat = 100

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
        // Instantiate CategoriesViewController from storyboard "AppStarting"
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "Categories")

        // Ensure we got the right type and pass the selected category
        if let categoriesVC = vc as? CategoriesViewController {
            categoriesVC.category = title
            categoriesVC.title = title
            categoriesVC.hidesBottomBarWhenPushed = true
            navigationController?.setNavigationBarHidden(false, animated: true)
            navigationController?.pushViewController(categoriesVC, animated: true)
        } else {
            assertionFailure("Storyboard ID 'Categories' is not a CategoriesViewController.")
        }
    }

    // Helper: map category title to background asset name
    private func categoryBackgroundAsset(for title: String) -> String? {
        switch title {
        case "Electronics": return "ElectronicsBG"
        case "Tools":       return "ToolsBG"
        case "Events":      return "EventsBG"
        case "Fitness":     return "FitnessBG"
        case "Hobbies":     return "HobbiesBG"
        case "Outdoor":     return "OutdoorBG"
        default:            return nil
        }
    }

    // MARK: - UICollectionViewDataSource (single implementation branching by collection)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === trendingCollectionView {
            return trendingItems.count
        }
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === trendingCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TrendingItemCell.reuseID, for: indexPath) as! TrendingItemCell
            let item = trendingItems[indexPath.item]
            cell.configure(with: item, currencyFormatter: currencyFormatter)
            cell.onRentTapped = { [weak self] in
                guard let self = self else { return }
                let nibName = "RequestViewController"
                let requestVC: RequestViewController
                if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                   Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                    requestVC = RequestViewController(nibName: nibName, bundle: nil)
                } else {
                    requestVC = RequestViewController()
                }
                requestVC.configure(with: item)
                requestVC.title = "Request"
                requestVC.hidesBottomBarWhenPushed = true
                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(requestVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: requestVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
            // Owner name removed from trending UI; no resolution or setting here.
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Category", for: indexPath) as? CategoryCollectionViewCell else {
            assertionFailure("Could not dequeue CategoryCollectionViewCell with identifier 'Category'")
            return UICollectionViewCell()
        }

        let item = categories[indexPath.item]
        cell.categoryLabel.text = item.title

        // Background image from assets (full-bleed)
        if let assetName = categoryBackgroundAsset(for: item.title) {
            cell.categoryBg.image = UIImage(named: assetName)
            cell.categoryBg.contentMode = .scaleAspectFill
            cell.categoryBg.clipsToBounds = true
        } else {
            cell.categoryBg.image = nil
        }

        // Foreground icon (SF Symbol) and style
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular, scale: .medium)
        cell.categoryImage.preferredSymbolConfiguration = config
        cell.categoryImage.image = UIImage(systemName: item.systemImageName)
        // Light icon tint for readability on photos
        cell.categoryImage.tintColor = UIColor(white: 1.0, alpha: 0.92)

        // Label styling for readability
        cell.categoryLabel.textColor = .white
        cell.categoryLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        // Optional subtle text shadow to help over bright areas
        cell.categoryLabel.shadowColor = UIColor.black.withAlphaComponent(0.35)
        cell.categoryLabel.shadowOffset = CGSize(width: 0, height: 1)

        // Rounded corners on the tile
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true

        // Clear background so the asset shows cleanly
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear

        return cell
    }

    // MARK: - UICollectionViewDelegate (single implementation branching by collection)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === trendingCollectionView {
            let item = trendingItems[indexPath.item]
            openItem(item)
            return
        }
        let item = categories[indexPath.item]
        pushCategories(title: item.title)
    }

    // MARK: - UICollectionViewDelegateFlowLayout (size only for trending; categories use compositional layout)
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView === trendingCollectionView {
            let height = collectionView.bounds.height
            return CGSize(width: 280, height: height)
        }
        // Not used for categories; compositional layout controls it.
        return CGSize(width: 70, height: 70)
    }

    // MARK: - UITabBarDelegate

    // featured item 1
    @IBOutlet weak var item1Image: UIImageView!
    @IBOutlet weak var item1Name: UILabel!
    @IBOutlet weak var item1Rate: UILabel!
    @IBOutlet weak var item1Rating: UILabel!
    @IBOutlet weak var item1Distance: UILabel!
    @IBOutlet weak var item1CardView: UIView!
    @IBOutlet weak var rentButton1: UIButton!
    @IBOutlet weak var item1owner: UILabel!
    
    // featured item 2
    @IBOutlet weak var item2Image: UIImageView!
    @IBOutlet weak var item2Name: UILabel!
    @IBOutlet weak var item2Rate: UILabel!
    @IBOutlet weak var item2Rating: UILabel!
    @IBOutlet weak var item2Distance: UILabel!
    @IBOutlet weak var item2CardView: UIView!
    @IBOutlet weak var rentButton2: UIButton!
    @IBOutlet weak var item2owner: UILabel!
    
    // featured item 3
    @IBOutlet weak var item3Image: UIImageView!
    @IBOutlet weak var item3Name: UILabel!
    @IBOutlet weak var item3Rate: UILabel!
    @IBOutlet weak var item3Rating: UILabel!
    @IBOutlet weak var item3Distance: UILabel!
    @IBOutlet weak var item3CardView: UIView!
    @IBOutlet weak var rentButton3: UIButton!
    @IBOutlet weak var item3owner: UILabel!
    
    // featured item 4
    @IBOutlet weak var item4Image: UIImageView!
    @IBOutlet weak var item4Name: UILabel!
    @IBOutlet weak var item4Rate: UILabel!
    @IBOutlet weak var item4Rating: UILabel!
    @IBOutlet weak var item4Distance: UILabel!
    @IBOutlet weak var item4CardView: UIView!
    @IBOutlet weak var rentButton4: UIButton!
    @IBOutlet weak var item4owner: UILabel!
    
    // MARK: - Greeting helper
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 0..<12:
            // 12:00am - 11:59am
            greeting = "Good morning"
        case 12..<16:
            // 12:00pm - 3:59pm
            greeting = "Good afternoon"
        default:
            // 4:00pm - 11:59pm
            greeting = "Good evening"
        }
        
        greetingTop?.text = greeting
    }
}

// MARK: - Location handling (sheet + persistence)
private extension HomeViewController {
    func refreshLocationButtonTitle() {
        // Always use full geocodable address for accurate distance calculations
        if SavedAddressesStore.shared.getDefaultSelectedAddress() == nil {
            // Use full geocodable default for DistanceService (same for all users)
            let defaultGeocodable = "SRM Institute of Science and Technology, Kattankulathur, Tamil Nadu, India"
            SavedAddressesStore.shared.setDefaultSelectedAddress(defaultGeocodable)
        }

        let storedAddress = SavedAddressesStore.shared.getDefaultSelectedAddress() ?? "SRMIST"
        
        // Extract only the city or label (first meaningful component) for display
        let displayText: String = {
            let trimmed = storedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "SRMIST" }
            
            // Split by comma and take the first non-empty part (typically city or label)
            let components = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Return the first meaningful component
            if let firstComponent = components.first(where: { !$0.isEmpty }) {
                return firstComponent
            }
            
            return trimmed
        }()
        
        locationTapped?.setTitle(displayText, for: .normal)
        locationTapped?.setTitleColor(UIColor(red: 112/255, green: 167/255, blue: 180/255, alpha: 1.0), for: .normal) // brand blue
        locationTapped?.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)

        // Ensure single-line display with truncation
        configureLocationButtonAppearance()
    }

    // Build a precise geocodable string from a backend Address
    func makeFullAddressString(from addr: Address) -> String {
        // Prefer full name/phone only for display; geocoding uses address fields
        let parts = [
            addr.address_line1,
            addr.address_line2,
            addr.city,
            addr.state,
            addr.postal_code,
            addr.country
        ]
        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @IBAction func locationTappedAction(_ sender: UIButton) {
        // Debug aid: verify the sender is our outlet (helps catch wiring to the wrong control in debug)
        assert(locationTapped == nil || sender === locationTapped, "locationTappedAction fired from a different control than locationTapped outlet.")

        let vc = LocationSelectorViewController()

        if #available(iOS 15.0, *) {
            vc.modalPresentationStyle = .pageSheet
        } else {
            // Best-effort similar presentation on older iOS
            vc.modalPresentationStyle = .pageSheet
        }

        vc.onSelectedAddress = { [weak self] _ in
            self?.refreshLocationButtonTitle()
        }

        // NEW: push ManualAddressViewController
        vc.onEnterManualAddress = { [weak self] completion in
            guard let self = self else { return }
            let form = ManualAddressViewController()
            // If you want to prefill from current location, you can set form.prefillCity/state/country
            form.onSaved = { saved in
                // Build a short display title for the button
                let display = [saved.label, saved.city, saved.state].compactMap { $0 }.first ?? saved.city
                // Build a precise geocodable string for distance computations
                let fullString = self.makeFullAddressString(from: saved)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                self.refreshLocationButtonTitle()
                completion(display)
            }
            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(form, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: form)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }

        // NEW: push ManageAddressesViewController
        vc.onManageSavedAddresses = { [weak self] in
            guard let self = self else { return }
            let list = ManageAddressesViewController()
            list.onPicked = { [weak self] addr in
                guard let self = self else { return }
                // Short title for UI
                let display = [addr.label, addr.city, addr.state].compactMap { $0 }.first ?? addr.city
                // Precise geocodable string for DistanceService
                let fullString = self.makeFullAddressString(from: addr)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                self.refreshLocationButtonTitle()
            }
            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(list, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: list)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }

        if let sheet = vc.presentationController as? UISheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }

        // Light haptic to match the feel of a sheet opening
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        present(vc, animated: true) {
            generator.impactOccurred()
        }
    }

    func presentSavedAddressesManager() {
        // This method is no longer used by the sheet; keeping it for compatibility
        let listVC = ManageAddressesViewController()
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(listVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: listVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    func presentAddAddressPrompt() {
        // Replaced by ManualAddressViewController; keeping stub for compatibility.
        let form = ManualAddressViewController()
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(form, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: form)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

// MARK: - Home header image rotation + slide animation (Aspect Fit)
private extension HomeViewController {

    func startHomeImageRotation() {
        stopHomeImageRotation()
        guard !rotatingImageNames.isEmpty else { return }
        imageRotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentHomeImageIndex = (self.currentHomeImageIndex + 1) % self.rotatingImageNames.count
            self.updateHomeImage(animated: true)
        }
    }

    func stopHomeImageRotation() {
        imageRotationTimer?.invalidate()
        imageRotationTimer = nil
    }

    func updateHomeImage(animated: Bool) {
        guard let imageView = homeimage, !rotatingImageNames.isEmpty else {
            return
        }

        // Ensure the image view has a valid size
        guard imageView.bounds.width > 0, imageView.bounds.height > 0 else {
            return
        }

        let name = rotatingImageNames[currentHomeImageIndex]
        let nextImage = UIImage(named: name)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        guard animated else {
            imageView.image = nextImage
            return
        }

        slideInFromRight(newImage: nextImage, in: imageView, duration: 0.35)
    }

    // Slides inside the image view’s bounds so it never overflows
    func slideInFromRight(newImage: UIImage?, in imageView: UIImageView, duration: TimeInterval) {
        imageView.layoutIfNeeded()
        let baseFrame = imageView.bounds

        // Outgoing snapshot
        let outgoing = UIImageView(image: imageView.image)
        outgoing.frame = baseFrame
        outgoing.contentMode = .scaleAspectFit
        outgoing.clipsToBounds = true

        // Incoming image starts to the right
        let incoming = UIImageView(image: newImage)
        incoming.frame = baseFrame
        incoming.contentMode = .scaleAspectFit
        incoming.clipsToBounds = true
        incoming.transform = CGAffineTransform(translationX: baseFrame.width, y: 0)

        // Add inside imageView (which clips)
        imageView.addSubview(outgoing)
        imageView.addSubview(incoming)

        // Hide the real content during animation
        let previousImage = imageView.image
        imageView.image = nil

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: {
            outgoing.transform = CGAffineTransform(translationX: -baseFrame.width, y: 0)
            incoming.transform = .identity
        }, completion: { _ in
            imageView.image = newImage
            outgoing.removeFromSuperview()
            incoming.removeFromSuperview()

            // Safety fallback if newImage was nil for any reason
            if imageView.image == nil {
                imageView.image = previousImage
            }
        })
    }

    // Install glass effect on all four featured cards
    func applyGlassToFeaturedCardsIfNeeded() {
        let cards: [UIView?] = [item1CardView, item2CardView, item3CardView, item4CardView]
        for card in cards {
            guard let v = card else { continue }
            // Whiter glass: heavier blur + white tint overlay + slightly stronger border
            v.applyGlassEffect(
                cornerRadius: 16,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: .white,
                tintAlpha: 0.14
            )
        }

        // Optional: give images slight rounding to match the card
        [item1Image, item2Image, item3Image, item4Image].forEach {
            $0?.clipsToBounds = true
            $0?.layer.cornerRadius = 12
        }
    }

    // Install glass effect on Rent buttons
    func applyGlassToRentButtonsIfNeeded() {
        let buttons: [UIButton?] = [rentButton1, rentButton2, rentButton3, rentButton4]
        for b in buttons {
            guard let v = b else { continue }

            // Keep light look
            let tintColorOverride: UIColor = .white
            let titleColor: UIColor = .label

            v.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            v.setTitleColor(titleColor, for: .normal)
            v.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)

            v.applyGlassEffect(
                cornerRadius: 16,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: tintColorOverride,
                tintAlpha: 0.20
            )
        }
    }

    // Round glass containers for header buttons (notificationBell, additemHome)
    func applyGlassToHeaderRoundButtons() {
        // Desired container size; adjust if you need bigger/smaller circles
        let containerSide: CGFloat = 44

        // Brand teal color used across the app
        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

        func ensureContainer(for button: UIButton, existing: inout UIView?) {
            if let container = existing {
                // Keep existing wrapper but make it a solid circle (no glass)
                container.backgroundColor = brandTeal
                container.layer.cornerRadius = containerSide / 2
                container.layer.masksToBounds = false
                // Optional soft shadow to lift the circle slightly
                container.layer.shadowOpacity = 0.12
                container.layer.shadowRadius = 5
                container.layer.shadowOffset = CGSize(width: 0, height: 3)
                // Do NOT call applyGlassEffect anymore.
                // Don’t force icon tint here; you will set it in Interface Builder.
                return
            }

            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false

            if let superview = button.superview {
                superview.addSubview(wrapper)
                NSLayoutConstraint.activate([
                    wrapper.widthAnchor.constraint(equalToConstant: containerSide),
                    wrapper.heightAnchor.constraint(equalToConstant: containerSide),
                    wrapper.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    wrapper.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            } else {
                // Fallback: add to self.view if button has no superview (shouldn’t happen normally)
                view.addSubview(wrapper)
                NSLayoutConstraint.activate([
                    wrapper.widthAnchor.constraint(equalToConstant: containerSide),
                    wrapper.heightAnchor.constraint(equalToConstant: containerSide),
                    wrapper.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    wrapper.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            }

            // Solid circle (no glass)
            wrapper.backgroundColor = brandTeal
            wrapper.layer.cornerRadius = containerSide / 2
            wrapper.layer.masksToBounds = false
            wrapper.layer.shadowOpacity = 0.12
            wrapper.layer.shadowRadius = 5
            wrapper.layer.shadowOffset = CGSize(width: 0, height: 3)

            // Move the button inside the wrapper and center it
            button.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
            ])

            // Keep button visuals neutral so you can set icon color in IB
            button.backgroundColor = .clear
            button.contentEdgeInsets = .zero
            // Do NOT force template/white here; you’ll set Tint in the Inspector.

            existing = wrapper
        }

        if let bell = notificationBell {
            ensureContainer(for: bell, existing: &notificationContainer)
        }
        if let add = additemHome {
            ensureContainer(for: add, existing: &addItemContainer)
        }
    }
}

// MARK: - Featured items loading
private extension HomeViewController {

    func loadFeaturedItems() async {
        do {
            // Use ItemsService to fetch active items and enrich with rating stats from public.reviews
            // Fetch latest items, then take up to 4 for featured.
            let allItems = try await itemsService.fetchItems(category: "")
            let items = Array(allItems.prefix(4))
            await MainActor.run {
                self.applyFeatured(items: items)
            }
        } catch {
            await MainActor.run {
                self.applyFeatured(items: [])
            }
        }
    }

    func applyFeatured(items: [Item]) {
        let slots: [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?)] = [
            (item1Image, item1Name, item1Rate, item1Rating, item1Distance),
            (item2Image, item2Name, item2Rate, item2Rating, item2Distance),
            (item3Image, item3Name, item3Rate, item3Rating, item3Distance),
            (item4Image, item4Name, item4Rate, item4Rating, item4Distance)
        ]

        // Clear owner labels upfront
        [item1owner, item2owner, item3owner, item4owner].forEach { $0?.text = nil }

        for i in 0..<slots.count {
            let slot = slots[i]
            if i < items.count {
                let item = items[i]
                configureFeaturedSlot(slot, with: item)
                // Resolve and set owner name for this slot
                resolveOwnerName(for: item.owner_id, slotIndex: i)
            } else {
                clearFeaturedSlot(slot)
            }
        }
        self.featuredItems = items

        // Update trending with the same source (approximate "trending" as latest featured for now)
        updateTrendingItems(from: items)
    }

    func configureFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?), with item: Item) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel) = slot

        nameLabel?.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        rateLabel?.text = priceText
        // Make rate fully black and regular
        rateLabel?.textColor = .label
        rateLabel?.font = .systemFont(ofSize: 14, weight: .regular)

        // Rating: yellow star + actual rating from database
        if let avgRating = item.average_rating, let count = item.review_count, count > 0 {
            let ratingText = String(format: "%.1f", avgRating)
            // Show only the number (no "review/reviews" text)
            ratingLabel?.attributedText = makeYellowStarRatingText(valueText: ratingText, reviewsText: nil)
        } else {
            // No reviews yet - show placeholder
            ratingLabel?.attributedText = nil
            ratingLabel?.text = "No reviews"
            ratingLabel?.textColor = .secondaryLabel
            ratingLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        }


        // Distance: fetch road distance asynchronously and update label
        distanceLabel?.text = "..."
        Task { [weak distanceLabel] in
            let text = await DistanceService.shared.distanceText(for: item)
            await MainActor.run { distanceLabel?.text = text }
        }

        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            setImage(into: imageView, from: url)
        } else {
            imageView?.image = UIImage(systemName: "photo")
            imageView?.tintColor = .secondaryLabel
            imageView?.contentMode = .scaleAspectFill
            imageView?.clipsToBounds = true
        }
    }

    func clearFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?)) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel) = slot
        imageView?.image = nil
        nameLabel?.text = nil
        rateLabel?.text = nil
        ratingLabel?.attributedText = nil
        ratingLabel?.text = nil
        distanceLabel?.text = nil
    }

    func setImage(into imageView: UIImageView?, from url: URL) {
        guard let imageView = imageView else { return }

        if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
            imageView.image = cached
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            return
        }

        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
            DispatchQueue.main.async {
                imageView.image = img
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
            }
        }.resume()
    }

    // MARK: - Owner name resolution for featured items

    // Capitalize only the first letter of the provided string, leaving the rest unchanged.
    func capitalizingFirstLetter(_ s: String) -> String {
        guard let first = s.unicodeScalars.first else { return s }
        let firstChar = String(first).uppercased()
        let remainder = String(s.unicodeScalars.dropFirst())
        return firstChar + remainder
    }

    // Fetch owner display name via public.user_profiles; fallback to profiles if you still maintain it.
    func resolveOwnerName(for ownerId: String, slotIndex: Int) {
        Task {
            // Try user_profiles view first (publicly readable)
            if let name = try? await fetchName(from: "user_profiles", ownerId: ownerId), !name.isEmpty {
                await applyOwnerName(name, toSlotAt: slotIndex)
                return
            }

            // Optional fallback: legacy profiles table if present
            if let name = try? await fetchName(from: "profiles", ownerId: ownerId), !name.isEmpty {
                await applyOwnerName(name, toSlotAt: slotIndex)
                return
            }

            // Final fallback: "Owner"
            await applyOwnerName("Owner", toSlotAt: slotIndex)
        }
    }

    private func fetchName(from table: String, ownerId: String) async throws -> String? {
        struct NameDTO: Decodable { let full_name: String? }
        let response = try await SupabaseManager.shared.client
            .from(table)
            .select("full_name")
            .eq("id", value: ownerId)
            .single()
            .execute()

        if let data = response.data as? Data {
            let dto = try JSONDecoder().decode(NameDTO.self, from: data)
            return dto.full_name
        }
        return nil
    }

    @MainActor
    private func applyOwnerName(_ name: String, toSlotAt index: Int) {
        let display = capitalizingFirstLetter(name)
        switch index {
        case 0: item1owner?.text = display
        case 1: item2owner?.text = display
        case 2: item3owner?.text = display
        case 3: item4owner?.text = display
        default: break
        }
    }

    // MARK: - Rating attributed text helper (yellow star)
    private func makeYellowStarRatingText(valueText: String, reviewsText: String? = "(23)") -> NSAttributedString {
        // Build "★ 4.5 (23)" with only the star in systemYellow
        let star = "★"
        let space = " "
        let rest = [valueText, reviewsText].compactMap { $0 }.joined(separator: " ")
        let full = star + space + rest

        let attr = NSMutableAttributedString(string: full, attributes: [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 14, weight: .regular)
        ])

        if let starRange = full.range(of: star) {
            let ns = NSRange(starRange, in: full)
            attr.addAttribute(.foregroundColor, value: UIColor.systemYellow, range: ns)
        }
        return attr
    }
}

// MARK: - Listing section (empty vs manage)
private extension HomeViewController {

    enum ListingSectionState {
        case empty
        case manage
    }

    func checkAndUpdateListingSection() async {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(.empty)
            }
            return
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("id", head: true, count: .exact) // HEAD + count
                .eq("owner_id", value: userId)
                .execute()

            let hasAny = (response.count ?? 0) > 0
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(hasAny ? .manage : .empty)
            }
        } catch {
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(.empty)
            }
        }
    }

    func showListingSection(_ state: ListingSectionState) {
        switch state {
        case .empty:
            manageContainerView?.removeFromSuperview()
            manageContainerView = nil
            listingUIView?.isHidden = false
            additemHome?.isHidden = false
            startearninglabel?.isHidden = false
            startearningdownlabel?.isHidden = false

            adjustListingViewHeightIfFixed(target: 110)

        case .manage:
            listingUIView?.isHidden = false
            additemHome?.isHidden = true
            startearninglabel?.isHidden = true
            startearningdownlabel?.isHidden = true

            if manageContainerView == nil {
                manageContainerView = buildManageCardUI()
                if let container = manageContainerView, let host = listingUIView {
                    host.addSubview(container)
                    container.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        container.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                        container.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                        container.topAnchor.constraint(equalTo: host.topAnchor),
                        container.bottomAnchor.constraint(equalTo: host.bottomAnchor)
                    ])
                }
            }

            adjustListingViewHeightIfFixed(target: 160) // tweak 150–170 to taste
        }
        
        // Animate section visible after data is loaded (only on first load)
        if isListingDataLoaded, listingUIView?.alpha == 0 {
            UIView.animate(withDuration: 0.3) {
                self.listingUIView?.alpha = 1
            }
        }
    }

    // Try to find a fixed height constraint applied directly to listingUIView and update it.
    func adjustListingViewHeightIfFixed(target: CGFloat) {
        guard let host = listingUIView else { return }

        // Look for a height constraint where the view is firstItem (most common)
        if let heightConstraint = host.constraints.first(where: { $0.firstAttribute == .height && $0.relation == .equal }) {
            if abs(heightConstraint.constant - target) > 0.5 {
                heightConstraint.constant = target
                host.setNeedsLayout()
                host.layoutIfNeeded()
            }
            return
        }

        // Or a constraint in the superview targeting host’s height
        if let superview = host.superview {
            if let heightConstraint = superview.constraints.first(where: {
                ($0.firstItem as? UIView) === host && $0.firstAttribute == .height && $0.relation == .equal
            }) {
                if abs(heightConstraint.constant - target) > 0.5 {
                    heightConstraint.constant = target
                    superview.setNeedsLayout()
                    superview.layoutIfNeeded()
                }
            }
        }
    }

    func buildManageCardUI() -> UIView {
        let card = UIView()
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16

        // Glass with NO border
        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.0,      // ensure no border
            tintColorOverride: .white,
            tintAlpha: 0.14
        )
        // Safety: clear any border that might be set elsewhere
        card.layer.borderWidth = 0
        card.layer.borderColor = nil

        // Title
        let title = UILabel()
        title.text = "Manage Listings"
        title.font = .systemFont(ofSize: 18, weight: .semibold) // updated to system semibold 18
        title.textColor = .label

        // Horizontal actions row
        let actionsRow = UIStackView()
        actionsRow.axis = .horizontal
        actionsRow.alignment = .center
        actionsRow.distribution = .equalSpacing
        actionsRow.spacing = 28

        // Helper to make a round frosted button + caption
        func roundAction(symbol: String, title: String, selector: Selector) -> UIView {
            let wrapper = UIStackView()
            wrapper.axis = .vertical
            wrapper.alignment = .center
            wrapper.spacing = 8

            let circleSide: CGFloat = 56
            let circle = UIView()
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: circleSide),
                circle.heightAnchor.constraint(equalToConstant: circleSide)
            ])
            circle.layer.cornerRadius = circleSide / 2
            circle.applyGlassEffect(
                cornerRadius: circleSide / 2,
                style: .systemUltraThinMaterial, // visually close to .ultraThinMaterial
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.0, // no border on small circles either
                tintColorOverride: .white,
                tintAlpha: 0.20
            )
            circle.layer.borderWidth = 0
            circle.layer.borderColor = nil

            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.tintColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0) // brand blue
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 24),
                icon.heightAnchor.constraint(equalToConstant: 24)
            ])

            let tap = UITapGestureRecognizer(target: self, action: selector)
            circle.isUserInteractionEnabled = true
            circle.addGestureRecognizer(tap)
            circle.accessibilityTraits = .button
            circle.accessibilityLabel = title

            let caption = UILabel()
            caption.text = title
            caption.font = .systemFont(ofSize: 13, weight: .semibold)
            caption.textColor = .label

            wrapper.addArrangedSubview(circle)
            wrapper.addArrangedSubview(caption)
            return wrapper
        }

        let add = roundAction(symbol: "plus", title: "Add Item", selector: #selector(manageListItemTapped))
        let req = roundAction(symbol: "tray.and.arrow.down", title: "Requests", selector: #selector(manageRequestsTapped))
        let man = roundAction(symbol: "rectangle.stack", title: "Manage", selector: #selector(manageManageTapped))

        actionsRow.addArrangedSubview(UIView()) // Spacer left
        actionsRow.addArrangedSubview(add)
        actionsRow.addArrangedSubview(req)
        actionsRow.addArrangedSubview(man)
        actionsRow.addArrangedSubview(UIView()) // Spacer right

        // Vertical stack inside card
        let v = UIStackView(arrangedSubviews: [title, actionsRow])
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 12
        v.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    // MARK: - Manage actions remain unchanged...
    @objc func manageListItemTapped() { additemHomeTapped(additemHome ?? UIButton(type: .system)) }
    // Requests action now forwards to the same IBAction as the Home "Request" button
    @objc func manageRequestsTapped() { requestsButtonTapped(additemHome ?? UIButton(type: .system)) }
    @objc func manageManageTapped() {
        // Open Dashboard on the Listing segment as a pushed page (no tab bar)
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        guard let dashboard = sb.instantiateViewController(withIdentifier: "DashboardListing") as? DashboardViewController else {
            assertionFailure("Storyboard ID 'DashboardListing' is not a DashboardViewController.")
            return
        }
        dashboard.title = "My Listings"
        dashboard.initialSegment = 0 // Listing
        dashboard.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(dashboard, animated: true)
        } else {
            // Fallback: present inside a nav so we get a back button
            let nav = UINavigationController(rootViewController: dashboard)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    // MARK: - Thin teal rim helper (no center fill)
    func addTealRim(to view: UIView, color: UIColor, cornerRadius: CGFloat, thickness: CGFloat, opacity: Float) {
        // Remove previous rim layers
        view.layer.sublayers?
            .filter { $0.name?.hasPrefix("rimLayer_") == true || $0.name == "rimLayer_container" }
            .forEach { $0.removeFromSuperlayer() }

        let bounds = view.bounds.integral
        guard bounds.width > 0, bounds.height > 0 else { return }

        func makeGradientLayer(name: String, frame: CGRect, start: CGPoint, end: CGPoint) -> CAGradientLayer {
            let g = CAGradientLayer()
            g.name = name
            g.frame = frame
            g.colors = [
                color.withAlphaComponent(CGFloat(opacity)).cgColor,
                color.withAlphaComponent(0).cgColor
            ]
            g.startPoint = start
            g.endPoint = end
            return g
        }

        // Top rim
        let top = makeGradientLayer(name: "rimLayer_top",
                                    frame: CGRect(x: 0, y: 0, width: bounds.width, height: thickness),
                                    start: CGPoint(x: 0.5, y: 0.0),
                                    end: CGPoint(x: 0.5, y: 1.0))
        // Bottom rim
        let bottom = makeGradientLayer(name: "rimLayer_bottom",
                                       frame: CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness),
                                       start: CGPoint(x: 0.5, y: 1.0),
                                       end: CGPoint(x: 0.5, y: 0.0))
        // Left rim
        let left = makeGradientLayer(name: "rimLayer_left",
                                     frame: CGRect(x: 0, y: 0, width: thickness, height: bounds.height),
                                     start: CGPoint(x: 0.0, y: 0.5),
                                     end: CGPoint(x: 1.0, y: 0.5))
        // Right rim
        let right = makeGradientLayer(name: "rimLayer_right",
                                      frame: CGRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height),
                                      start: CGPoint(x: 1.0, y: 0.5),
                                      end: CGPoint(x: 0.0, y: 0.5))

        // Container masked to rounded rect
        let mask = CAShapeLayer()
        mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        mask.fillColor = UIColor.white.cgColor

        let container = CALayer()
        container.name = "rimLayer_container"
        container.frame = bounds
        container.masksToBounds = true
        container.cornerRadius = cornerRadius
        container.addSublayer(top)
        container.addSublayer(bottom)
        container.addSublayer(left)
        container.addSublayer(right)
        container.mask = mask

        view.layer.addSublayer(container)
    }
}

// MARK: - Trending UI (horizontal scroller inside trendingUiView)
private extension HomeViewController {

    func setupTrendingCollection() {
        guard trendingCollectionView == nil, let host = trendingUiView else { return }

        // Ensure host does not clip and matches background
        host.clipsToBounds = false
        host.backgroundColor = .systemGroupedBackground

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 14
        // Give more room above for rounded corners and below for shadow
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        // Match the surrounding background so cards blend with the screen
        cv.backgroundColor = .systemGroupedBackground
        cv.showsHorizontalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        // Do not clip shadows
        cv.clipsToBounds = false
        // Extra breathing room for shadows
        cv.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)

        host.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            cv.topAnchor.constraint(equalTo: host.topAnchor),
            cv.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        cv.dataSource = self
        cv.delegate = self
        cv.register(TrendingItemCell.self, forCellWithReuseIdentifier: TrendingItemCell.reuseID)
        trendingCollectionView = cv
    }

    func updateTrendingItems(from items: [Item]) {
        // Sort by highest rating first, then take top 6
        // Items with no reviews (nil rating) go to the end
        let sortedByRating = items.sorted { item1, item2 in
            let rating1 = item1.average_rating ?? 0
            let rating2 = item2.average_rating ?? 0
            let count1 = item1.review_count ?? 0
            let count2 = item2.review_count ?? 0
            
            // Prioritize items with reviews
            if count1 > 0 && count2 == 0 { return true }
            if count1 == 0 && count2 > 0 { return false }
            
            // Both have reviews or both don't - sort by rating
            return rating1 > rating2
        }
        
        trendingItems = Array(sortedByRating.prefix(6))
        trendingCollectionView?.reloadData()
    }

    // Resolve owner name for trending cells with caching
    // (UI no longer displays owner name in trending; function retained only if needed elsewhere)
    func resolveTrendingOwnerName(for ownerId: String, completion: @escaping (String) -> Void) {
        if let cached = ownerNameCache[ownerId] {
            completion(cached)
            return
        }

        Task {
            // Try user_profiles first (publicly readable)
            if let name = try? await fetchName(from: "user_profiles", ownerId: ownerId), !name.isEmpty {
                let display = capitalizingFirstLetter(name)
                ownerNameCache[ownerId] = display
                completion(display)
                return
            }
            // Optional fallback profiles
            if let name = try? await fetchName(from: "profiles", ownerId: ownerId), !name.isEmpty {
                let display = capitalizingFirstLetter(name)
                ownerNameCache[ownerId] = display
                completion(display)
                return
            }
            let display = "Owner"
            ownerNameCache[ownerId] = display
            completion(display)
        }
    }
}

// MARK: - TrendingItemCell (code-only)
private final class TrendingItemCell: UICollectionViewCell {

    static let reuseID = "TrendingItemCell"

    private let card = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    // Removed owner label from UI

    // Price styled as: colored currency + “ / day” in secondary
    private let priceStack = UIStackView()
    private let priceMainLabel = UILabel()
    private let priceSuffixLabel = UILabel()

    // Rating (star + value)
    private let ratingStack = UIStackView()
    private let ratingIcon = UIImageView()
    private let ratingLabel = UILabel()

    // Distance (icon + text)
    private let distanceStack = UIStackView()
    private let distanceIcon = UIImageView()
    private let distanceLabel = UILabel()

    private let rentButton = UIButton(type: .system)

    var onRentTapped: (() -> Void)?

    private let brandTeal = UIColor(red: 112/255, green: 167/255, blue: 180/255, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false

        // Card container
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = false
        contentView.addSubview(card)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Glass like screenshot
        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.30,
            tintColorOverride: .white,
            tintAlpha: 0.14,
            showsHighlight: true,
            highlightAlpha: 0.15
        )

        // Image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemBackground

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .label

        // Price stack
        priceStack.axis = .horizontal
        priceStack.alignment = .firstBaseline
        priceStack.spacing = 4
        priceStack.translatesAutoresizingMaskIntoConstraints = false

        // Make rate fully black and regular
        priceMainLabel.font = .systemFont(ofSize: 16, weight: .regular)
        priceMainLabel.textColor = .label

        priceSuffixLabel.font = .systemFont(ofSize: 16, weight: .regular)
        priceSuffixLabel.textColor = .label
        priceSuffixLabel.text = "/ day"

        priceStack.addArrangedSubview(priceMainLabel)
        priceStack.addArrangedSubview(priceSuffixLabel)

        // Rating stack
        ratingStack.axis = .horizontal
        ratingStack.alignment = .center
        ratingStack.spacing = 6
        ratingStack.translatesAutoresizingMaskIntoConstraints = false

        let starConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        ratingIcon.image = UIImage(systemName: "star.fill", withConfiguration: starConfig)
        ratingIcon.tintColor = UIColor.systemYellow
        ratingIcon.setContentHuggingPriority(.required, for: .horizontal)

        ratingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        ratingLabel.textColor = .label

        ratingStack.addArrangedSubview(ratingIcon)
        ratingStack.addArrangedSubview(ratingLabel)

        // Distance stack
        distanceStack.axis = .horizontal
        distanceStack.alignment = .center
        distanceStack.spacing = 6
        distanceStack.translatesAutoresizingMaskIntoConstraints = false

        let pinConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        distanceIcon.image = UIImage(systemName: "mappin.and.ellipse", withConfiguration: pinConfig)
        // Make the pin bluish
        distanceIcon.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        distanceIcon.setContentHuggingPriority(.required, for: .horizontal)

        distanceLabel.font = .systemFont(ofSize: 15, weight: .regular)
        distanceLabel.textColor = .secondaryLabel

        distanceStack.addArrangedSubview(distanceIcon)
        distanceStack.addArrangedSubview(distanceLabel)

        // Rent button (pill) - solid background instead of glass effect
        rentButton.translatesAutoresizingMaskIntoConstraints = false
        rentButton.setTitle("Rent", for: .normal)
        rentButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        // Teal text on off-white background
        rentButton.setTitleColor(brandTeal, for: .normal)
        rentButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)
        
        // CRITICAL: Enable user interaction and use solid background
        rentButton.isUserInteractionEnabled = true
        rentButton.backgroundColor = UIColor(white: 0.96, alpha: 1.0) // Soft off-white
        rentButton.layer.cornerRadius = 16
        rentButton.clipsToBounds = false
        
        // Subtle shadow
        rentButton.layer.shadowColor = UIColor.black.cgColor
        rentButton.layer.shadowOpacity = 0.15
        rentButton.layer.shadowRadius = 6
        rentButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        rentButton.addTarget(self, action: #selector(rentTapped), for: .touchUpInside)

        // Meta rows
        let row1 = UIStackView(arrangedSubviews: [priceStack, UIView(), ratingStack])
        row1.axis = .horizontal
        row1.alignment = .center
        row1.spacing = 8
        row1.translatesAutoresizingMaskIntoConstraints = false

        let row2 = UIStackView(arrangedSubviews: [distanceStack, UIView(), rentButton])
        row2.axis = .horizontal
        row2.alignment = .center
        row2.spacing = 8
        row2.translatesAutoresizingMaskIntoConstraints = false

        // Vertical stack content (image, title, rows) — owner removed
        let v = UIStackView(arrangedSubviews: [imageView, titleLabel, row1, row2])
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(v)

        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            imageView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }

    @objc private func rentTapped() {
        onRentTapped?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        priceMainLabel.text = nil
        ratingLabel.text = nil
        distanceLabel.text = nil
        onRentTapped = nil
    }

    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        titleLabel.text = item.title

        // Price “₹ 160 / day” fully black and regular
        let amount = NSNumber(value: item.price_per_day)
        let priceText = currencyFormatter.string(from: amount) ?? "\(item.price_per_day)"
        priceMainLabel.text = priceText
        priceSuffixLabel.text = "/ day"

        // Rating placeholder
        if let avgRating = item.average_rating, let count = item.review_count, count > 0 {
            ratingLabel.text = String(format: "%.1f", avgRating)
        } else {
            ratingLabel.text = "No Rating"
        }

        // Distance: fetch road distance asynchronously
        distanceLabel.text = "..."
        Task { [weak self] in
            guard let self = self else { return }
            let text = await DistanceService.shared.distanceText(for: item)
            await MainActor.run { self.distanceLabel.text = text }
        }

        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            // Lightweight image load with cache
            if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
                imageView.image = cached
            } else {
                let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
                URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                    guard let self = self, let data = data, let img = UIImage(data: data) else { return }
                    FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
                    DispatchQueue.main.async { self.imageView.image = img }
                }.resume()
            }
        } else {
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .secondaryLabel
            imageView.contentMode = .scaleAspectFit
        }
    }
}

// MARK: - Featured Rent button actions
extension HomeViewController {

    @IBAction func rentButton1Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(0) else { return }
        openRequestView(for: featuredItems[0])
    }

    @IBAction func rentButton2Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(1) else { return }
        openRequestView(for: featuredItems[1])
    }

    @IBAction func rentButton3Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(2) else { return }
        openRequestView(for: featuredItems[2])
    }

    @IBAction func rentButton4Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(3) else { return }
        openRequestView(for: featuredItems[3])
    }
}

// MARK: - Bottom tagline helper
private extension HomeViewController {
    func setBottomTagline() {
        guard let label = Homepagelastline else { return }

        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        let baseColor = label.textColor ?? .label
        let baseFont = label.font ?? UIFont.systemFont(ofSize: 14)

        // Build the base attributed text: "You  RentiWise" (two spaces to host the attachment)
        let text = "You  RentiWise"
        let attr = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: baseColor,
            .font: baseFont
        ])

        // Create a tinted SF Symbol heart as an attachment
        let heartAttachment = NSTextAttachment()
        // Use heart.fill symbol; render as template so we can tint
        let pointSize = baseFont.pointSize
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        if let heartImage = UIImage(systemName: "heart.fill", withConfiguration: config)?
            .withRenderingMode(.alwaysTemplate) {

            // Render the symbol tinted to brandTeal
            let tinted = heartImage.withTintColor(brandTeal, renderingMode: .alwaysOriginal)
            heartAttachment.image = tinted

            // Align the attachment vertically with text baseline
            // Make it roughly cap-height: scale to line height minus a small inset
            let lineHeight = baseFont.lineHeight
            let imageHeight = lineHeight * 0.9
            let imageWidth = tinted.size.width * (imageHeight / tinted.size.height)

            heartAttachment.bounds = CGRect(
                x: 0,
                y: (baseFont.descender).rounded(), // slight baseline alignment
                width: imageWidth,
                height: imageHeight
            )
        }

        let heartString = NSAttributedString(attachment: heartAttachment)

        // Find the spot between the two spaces after "You "
        if let rangeOfYou = (attr.string as NSString).range(of: "You ").toRange() {
            let insertIndex = rangeOfYou.upperBound // right after "You "
            attr.replaceCharacters(in: NSRange(location: insertIndex, length: 0), with: heartString)
        } else {
            // Fallback: insert near start if "You " not found
            attr.insert(heartString, at: 4)
        }

        label.attributedText = attr
    }
    
    // MARK: - Notification Badge
    
    func updateNotificationBadge() async {
        do {
            // Check if user is logged in first
            let session = try? await SupabaseManager.shared.client.auth.session
            guard let userId = session?.user.id.uuidString else {
                // Not logged in, hide badge
                await MainActor.run {
                    self.unreadNotificationCount = 0
                    self.updateBadgeVisibility()
                }
                return
            }
            
            // Fetch unread counts from both tables
            let extensionCount = try await fetchUnreadExtensionCount(for: userId)
            let returnCount = try await fetchUnreadReturnCount(for: userId)
            let totalCount = extensionCount + returnCount
            
            await MainActor.run {
                self.unreadNotificationCount = totalCount
                self.updateBadgeVisibility()
            }
        } catch {
            print("[Home] Error fetching unread notification count: \\(error)")
            await MainActor.run {
                self.unreadNotificationCount = 0
                self.updateBadgeVisibility()
            }
        }
    }
    
    private func fetchUnreadExtensionCount(for ownerId: String) async throws -> Int {
        struct CountResponse: Decodable {
            let count: Int
        }
        
        let response: [CountResponse] = try await SupabaseManager.shared.client
            .from("extension_requests")
            .select("count", head: false, count: .exact)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .or("is_read.is.null,is_read.eq.false")
            .execute()
            .value
        
        return response.first?.count ?? 0
    }
    
    private func fetchUnreadReturnCount(for ownerId: String) async throws -> Int {
        struct CountResponse: Decodable {
            let count: Int
        }
        
        let response: [CountResponse] = try await SupabaseManager.shared.client
            .from("return_requests")
            .select("count", head: false, count: .exact)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .or("is_read.is.null,is_read.eq.false")
            .execute()
            .value
        
        return response.first?.count ?? 0
    }
    
    private func updateBadgeVisibility() {
        guard let bell = notificationBell else { return }
        
        if unreadNotificationCount > 0 {
            // Show badge
            if notificationBadge == nil {
                createNotificationBadge(on: bell)
            }
            notificationBadge?.isHidden = false
            
            // Animate badge appearance
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
                self.notificationBadge?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.notificationBadge?.transform = .identity
                }
            }
        } else {
            // Hide badge with fade
            UIView.animate(withDuration: 0.2) {
                self.notificationBadge?.alpha = 0
            } completion: { _ in
                self.notificationBadge?.isHidden = true
                self.notificationBadge?.alpha = 1
            }
        }
    }
    
    private func createNotificationBadge(on button: UIButton) {
        // Remove existing badge if any
        notificationBadge?.removeFromSuperview()
        
        // Create red dot badge
        let badge = UIView()
        badge.backgroundColor = UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0) // Teal color
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow for depth
        badge.layer.shadowColor = UIColor.black.cgColor
        badge.layer.shadowOpacity = 0.3
        badge.layer.shadowRadius = 2
        badge.layer.shadowOffset = CGSize(width: 0, height: 1)
        badge.layer.masksToBounds = false
        
        // Add to button's superview (so it's not affected by button transforms)
        if let superview = button.superview {
            superview.addSubview(badge)
            
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 0),
                badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 0),
                badge.widthAnchor.constraint(equalToConstant: 12),
                badge.heightAnchor.constraint(equalToConstant: 12)
            ])
        }
        
        notificationBadge = badge
    }
}

